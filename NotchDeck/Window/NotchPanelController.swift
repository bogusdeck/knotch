// NotchPanelController.swift
// Owns the NSPanel and drives transitions between collapsed / peek / expanded states.
// All geometry and animation logic lives here; SwiftUI views are mounted via NSHostingView.

import AppKit
import Combine
import OSLog
import SwiftUI
import WebKit

private let logger = Logger(subsystem: "com.notchdeck.app", category: "PanelController")

@MainActor
final class NotchPanelController: NSObject {

    // MARK: - Properties

    private let panel: NotchPanel
    private var hostingView: NSHostingView<NotchRootView>?
    let viewModel: NotchViewModel
    private let configManager: ConfigManager
    var geometry: NotchGeometry

    /// Tracks the hover tracking area for peek behaviour.
    private var hoverTrackingArea: NSTrackingArea?

    /// Timer that fires after `peek_delay_ms` to transition from .collapsed → .peek
    private var peekTimer: Task<Void, Never>?

    /// Cancellables for config observers
    private var cancellables = Set<AnyCancellable>()

    /// Global event monitor to collapse the notch when clicking anywhere outside
    private var outsideClickMonitor: Any?

    /// Previous frontmost application stored before expanding so we can restore focus upon collapse
    private var previousFrontmostApp: NSRunningApplication?

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

        viewModel.onWebZoomToggled = { [weak self] in
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
                }
                if self.viewModel.isWebZoomed && newTab != .web {
                    self.viewModel.isWebZoomed = false
                }
                if self.viewModel.state == .expanded {
                    self.resizePanel(for: .expanded, animated: true)
                }
            }
            .store(in: &cancellables)

        viewModel.$isSettingsActive
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.viewModel.state == .expanded {
                    self.resizePanel(for: .expanded, animated: true)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWhatsAppUnreadChanged(_:)),
            name: .whatsAppUnreadCountChanged,
            object: nil
        )

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

        holderManager.$activeEmbeddedAppItem
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if self.viewModel.state == .expanded && self.viewModel.activeTab == .holder {
                    self.resizePanel(for: .expanded, animated: true)
                }
            }
            .store(in: &cancellables)

        viewModel.$activeTab
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if self.viewModel.state == .expanded && self.configManager.config.appearance.dynamicSizing {
                    self.resizePanel(for: .expanded, animated: true)
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
        hostingView.panelController = self
        hostingView.layer?.backgroundColor = .clear

        hostingView.onDragEntered = { [weak self] in
            guard let self else { return }
            logger.info("Drag entered NotchPanel!")
            self.peekTimer?.cancel()
            self.viewModel.isDraggingOverNotch = true
            if self.viewModel.state != .expanded {
                self.expand()
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.viewModel.activeTab = .holder
            }
        }

        hostingView.onDragExited = { [weak self] in
            guard let self else { return }
            self.viewModel.isDraggingOverNotch = false
        }

        hostingView.onPerformDrag = { [weak self] sender in
            guard let self else { return false }
            let urls = self.extractURLsFromPasteboard(sender.draggingPasteboard)
            self.viewModel.isDraggingOverNotch = false
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
        positionPanel()
        installHoverTracking()
        observeScreenChanges()

        // Start Dock drag monitoring so drags from the macOS Dock are sensed as they approach the notch
        DockDragMonitor.shared.onDragApproachingNotch = { [weak self] url, name in
            guard let self else { return }
            self.viewModel.isDraggingOverNotch = true
            if self.viewModel.state != .expanded {
                self.expand()
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.viewModel.activeTab = .holder
            }
        }

        DockDragMonitor.shared.onDragDroppedOnNotch = { [weak self] url in
            guard let self else { return }
            self.viewModel.isDraggingOverNotch = false
            if let url {
                self.holderManager.addItem(from: url)
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.viewModel.activeTab = .holder
            }
        }

        DockDragMonitor.shared.onDragCancelled = { [weak self] in
            guard let self else { return }
            self.viewModel.isDraggingOverNotch = false
        }

        DockDragMonitor.shared.start()

        logger.info("NotchPanel shown at \(self.panel.frame.debugDescription)")
    }

    private func extractURLsFromPasteboard(_ pb: NSPasteboard) -> [URL] {
        var results: [URL] = []
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            results.append(contentsOf: urls)
        }

        let dockType = NSPasteboard.PasteboardType("com.apple.dock.item")
        if let dockPlist = (pb.propertyList(forType: dockType) as? [String: Any]) ??
           (pb.data(forType: dockType).flatMap { (try? PropertyListSerialization.propertyList(from: $0, format: nil)) as? [String: Any] }) {
            results.append(contentsOf: extractURLsFromDockPlist(dockPlist))
        }

        if let filenames = pb.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            for name in filenames {
                results.append(URL(fileURLWithPath: name))
            }
        }
        if let string = pb.string(forType: .string) {
            if string.hasPrefix("file://"), let url = URL(string: string) {
                results.append(url)
            } else if FileManager.default.fileExists(atPath: string) {
                results.append(URL(fileURLWithPath: string))
            }
        }
        if let items = pb.pasteboardItems {
            for item in items {
                if let dockPlist = (item.propertyList(forType: dockType) as? [String: Any]) ??
                   (item.data(forType: dockType).flatMap { (try? PropertyListSerialization.propertyList(from: $0, format: nil)) as? [String: Any] }) {
                    results.append(contentsOf: extractURLsFromDockPlist(dockPlist))
                }
                if let str = item.string(forType: .fileURL) ?? item.string(forType: NSPasteboard.PasteboardType("public.file-url")),
                   let url = URL(string: str) {
                    results.append(url)
                }
            }
        }
        var unique: [URL] = []
        for u in results {
            if !unique.contains(u) {
                unique.append(u)
            }
        }
        return unique
    }

    private func extractURLsFromDockPlist(_ dict: [String: Any]) -> [URL] {
        var found: [URL] = []
        let target = (dict["tile-data"] as? [String: Any]) ?? dict

        if let fileData = target["file-data"] as? [String: Any],
           let urlString = fileData["_CFURLString"] as? String,
           let url = URL(string: urlString) {
            found.append(url)
        }
        if let bundleId = target["bundle-identifier"] as? String,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            found.append(appURL)
        }
        if let label = target["file-label"] as? String {
            let appURL = URL(fileURLWithPath: "/Applications/\(label).app")
            let sysURL = URL(fileURLWithPath: "/System/Applications/\(label).app")
            if FileManager.default.fileExists(atPath: appURL.path) {
                found.append(appURL)
            } else if FileManager.default.fileExists(atPath: sysURL.path) {
                found.append(sysURL)
            }
        }
        return found
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
        if viewModel.hasWhatsAppNotification {
            if viewModel.lastUnreadSource == "googlechat" {
                viewModel.activeTab = .googlechat
            } else {
                viewModel.activeTab = .whatsapp
            }
            viewModel.activeCustomTabId = nil
        }

        // Remember the currently frontmost app so we can cleanly return focus when collapsed
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousFrontmostApp = frontApp
        }

        withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
            viewModel.state = .expanded
        }
        resizePanel(for: .expanded, animated: true)

        // Treat NotchDeck as a full-fledged foreground application when expanded:
        // Switching to .regular activation policy gives NotchDeck genuine application focus,
        // isolating drawer interactions from background windows and ensuring WebKit maintains full document.hasFocus().
        NSApp.setActivationPolicy(.regular)
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.makeKeyAndOrderFront(nil)
        panel.makeMain()
        NSApp.activate(ignoringOtherApps: true)

        startOutsideClickMonitor()
    }

    func openSettings(category: SettingsCategory = .general) {
        expand()
        viewModel.openSettingsInsideNotch(category: category)
    }

    func collapse() {
        logger.debug("→ collapsed")
        peekTimer?.cancel()
        stopOutsideClickMonitor()

        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            viewModel.state = .collapsed
            viewModel.isSettingsActive = false
            viewModel.isTerminalZoomed = false
            viewModel.isWebZoomed = false
        }
        resizePanel(for: .collapsed, animated: true)

        // Revert to accessory mode when collapsed so it hides from Dock/switcher
        NSApp.setActivationPolicy(.accessory)
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)

        // Return focus to whichever app was previously active
        if let app = previousFrontmostApp ?? NSWorkspace.shared.frontmostApplication,
           app.bundleIdentifier != Bundle.main.bundleIdentifier {
            app.activate(options: [])
        }
        previousFrontmostApp = nil
    }

    func peek() {
        guard viewModel.state == .collapsed else { return }
        logger.debug("→ peek")
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
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
            let duration: TimeInterval
            let timingFunction: CAMediaTimingFunction
            switch state {
            case .expanded:
                duration = 0.38
                timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 1.0, 0.32, 1.0)
            case .collapsed:
                duration = 0.34
                timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.42, 1.0)
            case .peek:
                duration = 0.32
                timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 1.0, 0.32, 1.0)
            }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration          = duration
                ctx.timingFunction    = timingFunction
                ctx.allowsImplicitAnimation = true
                panel.animator().setFrame(targetFrame, display: true)
            } completionHandler: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.panel.setFrame(targetFrame, display: true)
                    self?.installHoverTracking()
                }
            }
        } else {
            panel.setFrame(targetFrame, display: true)
            installHoverTracking()
        }
    }

    func panelFrame(for state: NotchState) -> CGRect {
        let cfg = configManager.config.appearance
        switch state {
        case .collapsed:
            if viewModel.hasWhatsAppNotification {
                // Expand 10pt wider (5pt left & right) and 4pt taller (4pt bottom) so it peeks out around the physical notch
                let w = geometry.notchFrame.width + 10
                let h = geometry.notchFrame.height + 4
                return CGRect(
                    x: geometry.notchFrame.midX - w / 2,
                    y: geometry.notchFrame.maxY - h,
                    width: w,
                    height: h
                )
            }
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
            } else if holderManager.activeEmbeddedAppItem != nil && viewModel.activeTab == .holder {
                let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first
                let maxW = (screen?.visibleFrame.width ?? 1200) * 0.92
                let maxH = (screen?.visibleFrame.height ?? 800) * 0.82
                w = min(maxW, 980)
                h = min(maxH, 640)
            } else if viewModel.activeTab == .web {
                let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first
                if viewModel.isWebZoomed {
                    let maxW = (screen?.visibleFrame.width ?? 1200) * 0.94
                    let maxH = (screen?.visibleFrame.height ?? 800) * 0.88
                    w = min(maxW, 1180)
                    h = min(maxH, 760)
                } else {
                    let maxW = (screen?.visibleFrame.width ?? 1200) * 0.82
                    let maxH = (screen?.visibleFrame.height ?? 800) * 0.68
                    w = min(maxW, 860)
                    h = min(maxH, 520)
                }
            } else if cfg.dynamicSizing {
                let (dynW, dynH) = dynamicDimensions(for: viewModel.activeTab, isSettings: viewModel.isSettingsActive)
                w = dynW
                h = dynH
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

    private func dynamicDimensions(for tab: NotchTab, isSettings: Bool) -> (CGFloat, CGFloat) {
        if isSettings {
            return (660, 420)
        }
        if viewModel.activeCustomTabId != nil {
            return (640, 300)
        }
        if tab == .holder && holderManager.activeEmbeddedAppItem != nil {
            let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first
            let maxW = (screen?.visibleFrame.width ?? 1200) * 0.92
            let maxH = (screen?.visibleFrame.height ?? 800) * 0.82
            return (min(maxW, 980), min(maxH, 640))
        }
        switch tab {
        case .home:
            return (680, 245)
        case .notes:
            return (680, 380)
        case .terminal:
            return (720, 380)
        case .holder:
            return (660, 330)
        case .vpn:
            return (540, 230)
        case .shelf:
            return (620, 260)
        case .web, .whatsapp, .slack, .googlechat:
            let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first
            let maxW = (screen?.visibleFrame.width ?? 1200) * 0.92
            let maxH = (screen?.visibleFrame.height ?? 800) * 0.82
            return (min(maxW, 980), min(maxH, 640))
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
        panel.invalidateCursorRects(for: contentView)
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

    // MARK: - WhatsApp Notification Glow & Pill Expansion

    @objc private func handleWhatsAppUnreadChanged(_ notification: Notification) {
        let count = notification.userInfo?["count"] as? Int ?? 0
        let source = notification.userInfo?["source"] as? String ?? "whatsapp"
        Task { @MainActor in
            self.viewModel.lastUnreadSource = source
            withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) {
                self.viewModel.whatsAppUnreadCount = count
            }
            if self.viewModel.state == .collapsed {
                self.resizePanel(for: .collapsed, animated: true)
            }
        }
    }
}

extension Notification.Name {
    static let whatsAppUnreadCountChanged = Notification.Name("NotchDeckWhatsAppUnreadCountChanged")
}

// MARK: - NSTrackingArea hover callbacks

extension NotchPanelController {

    @objc(mouseEntered:)
    func mouseEntered(with event: NSEvent) {
        NSCursor.arrow.set()
        // Always cancel any pending collapse timer if mouse is back inside
        peekTimer?.cancel()
        handleHoverEnter()
    }

    func handleHoverEnter() {
        guard viewModel.state == .collapsed else { return }
        if geometry.hasNotch {
            if !geometry.notchFrame.contains(NSEvent.mouseLocation) {
                return
            }
        }
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

    @objc(mouseExited:)
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

    // MARK: - Outside click monitoring

    private func startOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                guard self.viewModel.state == .expanded else { return }
                let mouseLoc = NSEvent.mouseLocation
                // Only collapse if the click occurred strictly outside the expanded notch panel frame
                if !self.panel.frame.contains(mouseLoc) {
                    self.collapse()
                }
            }
        }
    }

    private func stopOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }
}

// MARK: - NSWindowDelegate

extension NotchPanelController: NSWindowDelegate {
}

// MARK: - NSDraggingDestination

extension NotchPanelController: NSDraggingDestination {

    func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        logger.info("NotchPanelController draggingEntered!")
        peekTimer?.cancel()
        viewModel.isDraggingOverNotch = true
        if viewModel.state != .expanded {
            expand()
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            viewModel.activeTab = .holder
        }
        return .copy
    }

    func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    func draggingExited(_ sender: (any NSDraggingInfo)?) {
        logger.info("NotchPanelController draggingExited")
        viewModel.isDraggingOverNotch = false
    }

    func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        return true
    }

    func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        logger.info("NotchPanelController performDragOperation!")
        viewModel.isDraggingOverNotch = false
        let urls = extractURLsFromPasteboard(sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        for url in urls {
            holderManager.addItem(from: url)
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            viewModel.activeTab = .holder
        }
        return true
    }
}

// MARK: - NotchHostingView (Custom Dragging Destination)

final class NotchHostingView<Content: View>: NSHostingView<Content> {

    weak var panelController: NotchPanelController?
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    var onPerformDrag: ((any NSDraggingInfo) -> Bool)?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    @MainActor required init(rootView: Content) {
        super.init(rootView: rootView)
        if #available(macOS 13.0, *) {
            self.sizingOptions = []
        }
        registerForDraggedTypes([
            .fileURL,
            .URL,
            .string,
            NSPasteboard.PasteboardType("public.item"),
            NSPasteboard.PasteboardType("public.data"),
            NSPasteboard.PasteboardType("public.content"),
            NSPasteboard.PasteboardType("com.apple.dock.item"),
            NSPasteboard.PasteboardType("com.apple.application-bundle"),
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
            NSPasteboard.PasteboardType("Apple URL pasteboard type"),
            NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url")
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
