// KeyboardShortcuts+Names.swift
// Centralised registration of all named shortcuts used by NotchDeck.
// Individual shortcuts are configured from config.toml (Phase 2).

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Show / hide the expanded notch panel.
    static let toggleNotch = Self("toggleNotch", default: .init(.space, modifiers: [.command, .shift]))

    /// Open the notch directly into the Quick Note input.
    static let quickNote = Self("quickNote", default: .init(.n, modifiers: [.command, .shift]))
}
