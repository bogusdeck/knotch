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

        // Accept mouse events without activating the panel
        acceptsMouseMovedEvents    = true
        ignoresMouseEvents         = false

        // Register for dragged types so WindowServer delivers drag events to the notch
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

    // MARK: - Focus management

    /// The panel can *become* key only when a text field inside it needs focus.
    override var canBecomeKey: Bool { true }

    /// Never become the main window — that would affect the app's active appearance.
    override var canBecomeMain: Bool { false }
}
