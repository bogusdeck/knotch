// NotchPanel.swift
// The borderless NSPanel that hosts all NotchDeck content.
// Deliberately non-activating so it never steals focus.

import AppKit

/// A transparent, borderless, non-activating panel positioned over the notch area.
final class NotchPanel: NSPanel {

    // MARK: - Init

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [
                .borderless,
                .nonactivatingPanel,
                .fullSizeContentView,
                .utilityWindow,
            ],
            backing: .buffered,
            defer: false
        )
        configure()
    }

    // MARK: - Configuration

    private func configure() {
        // Transparency
        isOpaque                  = false
        backgroundColor           = .clear
        hasShadow                 = false

        // Window level — sits above the menu bar but below system alerts
        level                     = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)

        // Appear on all Spaces and full-screen apps; never moves with the user
        collectionBehavior        = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]

        // Never appear in exposé / mission control as a separate window
        isExcludedFromWindowsMenu = true

        // Don't show a title bar or traffic lights
        titlebarAppearsTransparent = true
        titleVisibility            = .hidden

        // Keep the panel alive even when the app "deactivates"
        hidesOnDeactivate          = false

        // Automatically become key window on click
        becomesKeyOnlyIfNeeded     = false

        // Accept mouse events without activating the panel
        acceptsMouseMovedEvents    = true
        ignoresMouseEvents         = false
        enableCursorRects()

        // Register for dragged types so WindowServer delivers drag events to the notch
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

    // MARK: - Focus management

    /// The panel can become key to receive keyboard input.
    override var canBecomeKey: Bool { true }

    /// Can become the main window when expanded so Touch ID / Passkey authentication sheets,
    /// file open dialogs, and security prompts can present and anchor properly.
    override var canBecomeMain: Bool { true }

    // MARK: - Frame Constraining

    /// Prevents macOS AppKit from pushing the notch panel down below the menu bar.
    /// By default, NSWindow.constrainFrameRect forces all windows to stay within `screen.visibleFrame`,
    /// which shoves the notch panel completely down out of the hardware notch and into the desktop/browser.
    /// Overriding this allows the panel to sit exactly inside the hardware notch and menu bar at the top of the display.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    // MARK: - Minimum Size Override

    /// Prevents NSHostingView or AppKit from enforcing SwiftUI content fittingSize onto the window minSize,
    /// ensuring the panel can collapse completely and strictly to the physical notch geometry.
    override var minSize: NSSize {
        get { .zero }
        set { }
    }

    override var contentMinSize: NSSize {
        get { .zero }
        set { }
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            if !isKeyWindow {
                makeKey()
            }
            if !isMainWindow {
                makeMain()
            }
            if !NSApp.isActive {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        super.sendEvent(event)
    }
}

// MARK: - NSDraggingDestination

extension NotchPanel: NSDraggingDestination {

    func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        if let dest = delegate as? NSDraggingDestination, let op = dest.draggingEntered?(sender) {
            return op
        }
        return .copy
    }

    func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        if let dest = delegate as? NSDraggingDestination, let op = dest.draggingUpdated?(sender) {
            return op
        }
        return .copy
    }

    func draggingExited(_ sender: (any NSDraggingInfo)?) {
        if let dest = delegate as? NSDraggingDestination {
            dest.draggingExited?(sender)
        }
    }

    func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        if let dest = delegate as? NSDraggingDestination, let res = dest.prepareForDragOperation?(sender) {
            return res
        }
        return true
    }

    func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        if let dest = delegate as? NSDraggingDestination, let res = dest.performDragOperation?(sender) {
            return res
        }
        return false
    }
}
