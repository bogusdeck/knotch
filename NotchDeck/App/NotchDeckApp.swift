// NotchDeckApp.swift
// Entry point for NotchDeck.
// Uses AppKit lifecycle so we can control NSPanel creation precisely.

import AppKit
import SwiftUI

@main
struct NotchDeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No default window — everything is in AppDelegate.
        // We keep an empty Settings scene here as a placeholder; the real
        // Settings window is opened imperatively from the menu.
        Settings {
            SettingsPlaceholderView()
        }
    }
}

/// Minimal placeholder so SwiftUI doesn't complain about an empty Settings scene.
private struct SettingsPlaceholderView: View {
    var body: some View {
        Text("Settings")
            .frame(width: 400, height: 300)
    }
}
