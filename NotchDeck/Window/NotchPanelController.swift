// NotchPanelController.swift
// Owns the NSPanel and drives transitions between collapsed / peek / expanded states.
// All geometry and animation logic lives here; SwiftUI views are mounted via NSHostingView.

import AppKit
import Combine
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.notchdeck.app", category: "PanelController")

@MainActor
final class NotchPanelController: NSObject {

    // MARK: - Properties

    private let panel: NotchPanel
    private var hostingView: NSHostingView<NotchRootView>?
    let viewModel: NotchViewModel
    private let configManager: ConfigManager
    private var geometry: NotchGeometry

    /// Tracks the hover tracking area for peek behaviour.
    private var hoverTrackingArea: NSTrackingArea?

    /// Timer that fires after `peek_delay_ms` to transition from .collapsed → .peek
    private var peekTimer: Task<Void, Never>?

    /// Cancellables for config observers
    private var cancellables = Set<AnyCancellable>()

    let notesManager = NotesManager()
    let shelfManager = ShelfManager()
    let holderManager = HolderManager()
    let mediaManager = MediaManager()
    let calendarManager = CalendarManager()
    let widgetRegistry = WidgetRegistry()

    // MARK: - Init

    init(configManager: ConfigManager) {
        self.configManager = configManager
        self.geometry      = NotchGeometryDetector.detect()
        self.panel         = NotchPanel()
        self.viewModel     = NotchViewModel(geometry: geometry)
        super.init()

        viewModel.onExpandRequested = { [weak self] in
            self?.expand()
        }
        viewModel.onCollapseRequested = { [weak self] in
            self?.collapse()
        }
        viewModel.onPeekRequested = { [weak self] in
            self?.peek()
        }

        widgetRegistry.register(NotesWidget(notesManager: notesManager, viewModel: viewModel))
        widgetRegistry.register(ShelfWidget(shelfManager: shelfManager, copyOnDrop: configManager.config.general.copyOnDrop))
        widgetRegistry.register(HolderWidget(holderManager: holderManager))
        widgetRegistry.register(MediaWidget(mediaManager: mediaManager))
        widgetRegistry.register(TerminalWidget(viewModel: viewModel))
        widgetRegistry.syncConfiguredWidgets(configs: configManager.config.widgets)
        TerminalManager.shared.syncConfiguredSessions(widgets: configManager.config.widgets)

        viewModel.onTerminalZoomToggled = { [weak self] in
            guard let self = self else { return }
            if self.viewModel.state == .expanded {
                self.resizePanel(for: .expanded, animated: true)
            }
        }

        viewModel.$activeTab
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTab in
                guard let self = self else { return }
                if self.viewModel.isTerminalZoomed && newTab != .terminal {
                    self.viewModel.isTerminalZoomed = false
                    if self.viewModel.state == .expanded {
                        self.resizePanel(for: .expanded, animated: true)
                    }
                }
            }
            .store(in: &cancellables)

        observeConfig()
    }

    private func observeConfig() {
        configManager.$configError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self else { return }
                self.viewModel.configError = error
                if error != nil && self.viewModel.state == .collapsed {
                    self.peek()
                }
            }
            .store(in: &cancellables)

        configManager.$config
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newConfig in
                guard let self else { return }
                self.widgetRegistry.syncConfiguredWidgets(configs: newConfig.widgets)
                TerminalManager.shared.syncConfiguredSessions(widgets: newConfig.widgets)
                if self.viewModel.state != .collapsed {
                    self.resizePanel(for: self.viewModel.state, animated: true)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Show

    func show() {
        let rootView = NotchRootView(
            viewModel: viewModel,
            configManager: configManager,
            notesManager: notesManager,
            shelfManager: shelfManager,
            holderManager: holderManager,
            mediaManager: mediaManager,
            calendarManager: calendarManager,
            widgetRegistry: widgetRegistry
        )
        let hostingView = NotchHostingView(rootView: rootView)
        hostingView.layer?.backgroundColor = .clear

        hostingView.onDragEntered = { [weak self] in
            guard let self else { return }
            logger.info("Drag entered NotchPanel!")
            self.peekTimer?.cancel()
            if self.viewModel.state != .expanded {
                self.expand()
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.viewModel.activeTab = .holder
            }
        }

        hostingView.onPerformDrag = { [weak self] sender in
            guard let self else { return false }
            let urls = self.extractURLsFromPasteboard(sender.draggingPasteboard)
            guard !urls.isEmpty else { return false }
            for url in urls {
                self.holderManager.addItem(from: url)
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.viewModel.activeTab = .holder
            }
            return true
        }

        // Install mouse-tracking delegate
        panel.delegate = self

        // Set the hosting view
        panel.contentView = hostingView
        self.hostingView  = hostingView

        positionPanel()
        panel.orderFrontRegardless()
        installHoverTracking()
        observeScreenChanges()

        logger.info("NotchPanel shown at \(self.panel.frame.debugDescription)")
    }

    private func extractURLsFromPasteboard(_ pb: NSPasteboard) -> [URL] {
        var results: [URL] = []
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            results.append(contentsOf: urls)
        }
        if results.isEmpty, let filenames = pb.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            for name in filenames {
                results.append(URL(fileURLWithPath: name))
            }
        }
        if results.isEmpty, let string = pb.string(forType: .string) {
            if string.hasPrefix("file://"), let url = URL(string: string) {
                results.append(url)
            } else if FileManager.default.fileExists(atPath: string) {
                results.append(URL(fileURLWithPath: string))
            }
        }
        if results.isEmpty, let items = pb.pasteboardItems {
            for item in items {
                if let str = item.string(forType: .fileURL) ?? item.string(forType: NSPasteboard.PasteboardType("public.file-url")),
                   let url = URL(string: str) {
                    results.append(url)
                }
            }
        }
        return results
    }

    // MARK: - Positioning

    private func positionPanel() {
        let collapsedFrame = panelFrame(for: .collapsed)
        panel.setFrame(collapsedFrame, display: false)
    }

    // MARK: - State transitions

    func toggleExpanded() {
        switch viewModel.state {
        case .collapsed, .peek:
            expand()
        case .expanded:
            collapse()
        }
    }

    func expand() {
        logger.debug("→ expanded")
        peekTimer?.cancel()
        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
            viewModel.state = .expanded
        }
        resizePanel(for: .expanded, animated: true)
        // Panel must become key so text fields work
        panel.makeKeyAndOrderFront(nil)
    }

    func openSettings(category: SettingsCategory = .general) {
        expand()
        viewModel.openSettingsInsideNotch(category: category)
    }

    func collapse() {
        logger.debug("→ collapsed")
        peekTimer?.cancel()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            viewModel.state = .collapsed
            viewModel.isSettingsActive = false
            viewModel.isTerminalZoomed = false
        }
        resizePanel(for: .collapsed, animated: true)
        // Return focus to whichever app was previously active
        if let app = NSWorkspace.shared.frontmostApplication {
            app.activate(options: [])
        }
    }

    func peek() {
        guard viewModel.state == .collapsed else { return }
        logger.debug("→ peek")
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            viewModel.state = .peek
        }
        resizePanel(for: .peek, animated: true)
    }

    func openQuickNote() {
        expand()
        viewModel.activeTab = .notes
        viewModel.requestFocusOnNoteInput = true
    }

    func selectWidgetTab(id: String) {
        expand()
        if let tab = NotchTab(rawValue: id) {
            viewModel.activeTab = tab
            viewModel.activeCustomTabId = nil
        } else {
            viewModel.activeCustomTabId = id
        }
    }

    // MARK: - Panel resizing

    private func resizePanel(for state: NotchState, animated: Bool) {
        let targetFrame = panelFrame(for: state)

        if animated {
            let duration: TimeInterval = (state == .expanded) ? 0.36 : 0.32
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration          = duration
                ctx.timingFunction    = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                ctx.allowsImplicitAnimation = true
                panel.animator().setFrame(targetFrame, display: true)
            } completionHandler: { [weak self] in
                self?.installHoverTracking()
            }
        } else {
            panel.setFrame(targetFrame, display: true)
            installHoverTracking()
        }
    }

    private func panelFrame(for state: NotchState) -> CGRect {
        let cfg = configManager.config.appearance
        switch state {
        case .collapsed:
            return geometry.notchFrame

        case .peek:
            let w = geometry.notchFrame.width + 80
            let h = geometry.notchFrame.height + 44
            return CGRect(
                x: geometry.notchFrame.midX - w / 2,
                y: geometry.notchFrame.maxY - h,
                width: w,
                height: h
            )

        case .expanded:
            let w: CGFloat
            let h: CGFloat
            if viewModel.isTerminalZoomed && viewModel.activeTab == .terminal {
                let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first
                let maxW = (screen?.visibleFrame.width ?? 1200) * 0.90
                let maxH = (screen?.visibleFrame.height ?? 800) * 0.78
                w = min(maxW, 1040)
                h = min(maxH, 620)
            } else {
                w = CGFloat(cfg.expandedWidth)
                h = CGFloat(cfg.expandedHeight)
            }
            return CGRect(
                x: geometry.notchFrame.midX - w / 2,
                y: geometry.notchFrame.maxY - h,
                width: w,
                height: h
            )
        }
    }

    // MARK: - Hover tracking

    private func installHoverTracking() {
        guard let contentView = panel.contentView else { return }
        hoverTrackingArea.map { contentView.removeTrackingArea($0) }

        let area = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(area)
        hoverTrackingArea = area
    }

    // MARK: - Screen change notifications

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screensDidChange() {
        geometry = NotchGeometryDetector.detect()
        viewModel.geometry = geometry
        if viewModel.state == .collapsed {
            positionPanel()
        }
    }
}

// MARK: - NSTrackingArea hover callbacks

extension NotchPanelController {

    func mouseEntered(with event: NSEvent) {
        // Always cancel any pending collapse timer if mouse is back inside
        peekTimer?.cancel()
        handleHoverEnter()
    }

    func handleHoverEnter() {
        guard viewModel.state == .collapsed else { return }
        let delayMs = min(configManager.config.general.peekDelayMs, 60)
        peekTimer?.cancel()
        peekTimer = Task {
            try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            guard !Task.isCancelled else { return }
            if self.configManager.config.general.hoverToExpand {
                self.expand()
            } else if self.configManager.config.general.hoverToPeek {
                self.peek()
            }
        }
    }

    func mouseExited(with event: NSEvent) {
        handleHoverExit()
    }

    func handleHoverExit() {
        peekTimer?.cancel()
        if viewModel.state == .peek {
            collapse()
        } else if viewModel.state == .expanded && configManager.config.general.hoverToExpand {
            // Keep expanded if note input or text field is actively focused
            guard !viewModel.requestFocusOnNoteInput else { return }
            peekTimer = Task {
                try? await Task.sleep(nanoseconds: 700_000_000) // 700ms grace period
                guard !Task.isCancelled else { return }
                let mouseLocation = NSEvent.mouseLocation
                if !self.panel.frame.contains(mouseLocation) {
                    self.collapse()
                }
            }
        }
    }
}

// MARK: - NSWindowDelegate (click-outside-to-collapse)

extension NotchPanelController: NSWindowDelegate {

    func windowDidResignKey(_ notification: Notification) {
        // Collapse when another window becomes key, unless we're intentionally
        // keeping a text field focused
        if viewModel.state == .expanded && !viewModel.requestFocusOnNoteInput {
            collapse()
        }
    }
}

// MARK: - NotchHostingView (Custom Dragging Destination)

final class NotchHostingView<Content: View>: NSHostingView<Content> {

    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    var onPerformDrag: ((any NSDraggingInfo) -> Bool)?

    @MainActor required init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDraggedTypes([
            .fileURL,
            .URL,
            .string,
            NSPasteboard.PasteboardType("public.item"),
            NSPasteboard.PasteboardType("com.apple.application-bundle"),
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        onDragEntered?()
        return .copy
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        onDragExited?()
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        return onPerformDrag?(sender) ?? false
    }
}
