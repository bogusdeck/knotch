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
    private let viewModel: NotchViewModel
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

        widgetRegistry.register(NotesWidget(notesManager: notesManager, viewModel: viewModel))
        widgetRegistry.register(ShelfWidget(shelfManager: shelfManager, copyOnDrop: configManager.config.general.copyOnDrop))
        widgetRegistry.register(MediaWidget(mediaManager: mediaManager))
        widgetRegistry.register(TerminalWidget())
        widgetRegistry.syncConfiguredWidgets(configs: configManager.config.widgets)
        TerminalManager.shared.syncConfiguredSessions(widgets: configManager.config.widgets)

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
            mediaManager: mediaManager,
            calendarManager: calendarManager,
            widgetRegistry: widgetRegistry
        )
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.layer?.backgroundColor = .clear

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

    // MARK: - Positioning

    private func positionPanel() {
        // In collapsed state the panel exactly overlaps the notch
        let collapsedFrame = geometry.notchFrame
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
        viewModel.state = .expanded
        resizePanel(for: .expanded, animated: true)
        // Panel must become key so text fields work
        panel.makeKeyAndOrderFront(nil)
    }

    func collapse() {
        logger.debug("→ collapsed")
        peekTimer?.cancel()
        viewModel.state = .collapsed
        resizePanel(for: .collapsed, animated: true)
        // Return focus to whichever app was previously active
        if let app = NSWorkspace.shared.frontmostApplication {
            app.activate(options: [])
        }
    }

    func peek() {
        guard viewModel.state == .collapsed else { return }
        logger.debug("→ peek")
        viewModel.state = .peek
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
            // Use NSAnimationContext for the window frame — SwiftUI handles internal animation
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration          = 0.35
                ctx.timingFunction    = CAMediaTimingFunction(name: .easeInEaseOut)
                ctx.allowsImplicitAnimation = true
                panel.animator().setFrame(targetFrame, display: true)
            }
        } else {
            panel.setFrame(targetFrame, display: true)
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
            let w = CGFloat(cfg.expandedWidth)
            let h = CGFloat(cfg.expandedHeight)
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
        guard viewModel.state == .collapsed else { return }
        let delayMs = configManager.config.general.peekDelayMs
        peekTimer?.cancel()
        peekTimer = Task {
            try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            if !Task.isCancelled { self.peek() }
        }
    }

    func mouseExited(with event: NSEvent) {
        peekTimer?.cancel()
        if viewModel.state == .peek {
            collapse()
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
