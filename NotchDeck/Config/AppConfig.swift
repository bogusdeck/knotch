// AppConfig.swift
// Swift representation of config.toml.

import Foundation

/// Root configuration object. Mirrors config.toml exactly.
struct AppConfig: Sendable, Equatable {
    var general:    GeneralConfig    = .default
    var shortcuts:  ShortcutsConfig  = .default
    var appearance: AppearanceConfig = .default
    var layout:     LayoutConfig     = .default
    var widgets:    [WidgetConfig]   = []
}

// MARK: - General

struct GeneralConfig: Sendable, Equatable {
    var screen: String = "builtin"
    var hoverToPeek: Bool = true
    var hoverToExpand: Bool = true
    var peekDelayMs: Int = 150
    var launchAtLogin: Bool = false
    var copyOnDrop: Bool = false
    var showMenuBarIcon: Bool = false

    static let `default` = GeneralConfig()
}

// MARK: - Shortcuts

struct ShortcutsConfig: Sendable, Equatable {
    var toggle: String = "cmd+shift+space"
    var quickNote: String = "cmd+shift+n"

    static let `default` = ShortcutsConfig()
}

// MARK: - Appearance

struct AppearanceConfig: Sendable, Equatable {
    var theme: String = "dark"
    var accent: String = "#7C5CFF"
    var expandedWidth: Int = 640
    var expandedHeight: Int = 260
    var cornerRadius: Int = 22
    var dynamicSizing: Bool = false

    static let `default` = AppearanceConfig()
}

// MARK: - Layout

struct LayoutConfig: Sendable, Equatable {
    var tabs: [String] = ["home", "notes", "googlechat", "whatsapp", "slack", "web", "terminal", "vpn"]
    var home: [String] = ["media", "clock", "calendar", "vpn-status"]

    static let `default` = LayoutConfig()
}

// MARK: - Widgets

struct WidgetConfig: Sendable, Equatable {
    var id: String = ""
    var type: String = ""
    var title: String = ""
    var icon: String? = nil
    var shortcut: String? = nil

    // For action widgets
    var statusCommand: String? = nil
    var statusIntervalS: Int = 10
    var statusRegex: String? = nil
    var buttons: [WidgetButtonConfig] = []

    // For terminal widgets
    var command: String? = nil
    var cwd: String? = nil
    var autostart: Bool = false

    // For shell widgets
    var intervalS: Int = 30

    // For web widgets
    var url: String? = nil
    var path: String? = nil
    var allowShell: Bool = false

    // For AppleScript / URL actions
    var applescript: String? = nil
    var openUrl: String? = nil
}

struct WidgetButtonConfig: Sendable, Equatable {
    var label: String = ""
    var command: String? = nil
    var applescript: String? = nil
    var openUrl: String? = nil
}
