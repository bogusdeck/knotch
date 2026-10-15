// TOMLParser.swift
// Parses config.toml into AppConfig using TOMLKit.

import Foundation
import OSLog
import TOMLKit

private let logger = Logger(subsystem: "com.notchdeck.app", category: "TOMLParser")

enum TOMLParser {

    /// Parses raw TOML text into an AppConfig.
    /// On success returns the config. On failure throws ConfigError.parseError.
    static func parse(_ text: String) throws(ConfigError) -> AppConfig {
        let root: TOMLTable
        do {
            root = try TOMLTable(string: text)
        } catch let parseError as TOMLParseError {
            let line = parseError.source.begin.line
            let msg = parseError.description
            logger.error("TOML parse error at line \(line): \(msg, privacy: .public)")
            throw ConfigError.parseError(line: line, message: msg)
        } catch {
            let line = extractLineNumber(from: error.localizedDescription)
            let msg = error.localizedDescription
            logger.error("TOML error: \(msg, privacy: .public)")
            throw ConfigError.parseError(line: line, message: msg)
        }

        var config = AppConfig()

        if let table = root["general"]?.table {
            config.general = parseGeneral(table)
        }
        if let table = root["shortcuts"]?.table {
            config.shortcuts = parseShortcuts(table)
        }
        if let table = root["appearance"]?.table {
            config.appearance = parseAppearance(table)
        }
        if let table = root["layout"]?.table {
            config.layout = parseLayout(table)
        }
        if let widgetArray = root["widgets"]?.array {
            config.widgets = widgetArray.compactMap { $0.table }.map(parseWidget)
        }

        return config
    }

    // MARK: - Section Parsers

    private static func parseGeneral(_ table: TOMLTable) -> GeneralConfig {
        var general = GeneralConfig.default
        if let v = table["screen"]?.string { general.screen = v }
        if let v = table["hover_to_peek"]?.bool { general.hoverToPeek = v }
        if let v = table["peek_delay_ms"]?.int { general.peekDelayMs = v }
        if let v = table["launch_at_login"]?.bool { general.launchAtLogin = v }
        return general
    }

    private static func parseShortcuts(_ table: TOMLTable) -> ShortcutsConfig {
        var shortcuts = ShortcutsConfig.default
        if let v = table["toggle"]?.string { shortcuts.toggle = v }
        if let v = table["quick_note"]?.string { shortcuts.quickNote = v }
        return shortcuts
    }

    private static func parseAppearance(_ table: TOMLTable) -> AppearanceConfig {
        var appearance = AppearanceConfig.default
        if let v = table["theme"]?.string { appearance.theme = v }
        if let v = table["accent"]?.string { appearance.accent = v }
        if let v = table["expanded_width"]?.int { appearance.expandedWidth = v }
        if let v = table["expanded_height"]?.int { appearance.expandedHeight = v }
        if let v = table["corner_radius"]?.int { appearance.cornerRadius = v }
        return appearance
    }

    private static func parseLayout(_ table: TOMLTable) -> LayoutConfig {
        var layout = LayoutConfig.default
        if let array = table["tabs"]?.array {
            let items = array.compactMap(\.string)
            if !items.isEmpty { layout.tabs = items }
        }
        if let array = table["home"]?.array {
            let items = array.compactMap(\.string)
            if !items.isEmpty { layout.home = items }
        }
        return layout
    }

    private static func parseWidget(_ table: TOMLTable) -> WidgetConfig {
        var widget = WidgetConfig()
        if let v = table["id"]?.string { widget.id = v }
        if let v = table["type"]?.string { widget.type = v }
        if let v = table["title"]?.string { widget.title = v }
        if let v = table["icon"]?.string { widget.icon = v }
        if let v = table["shortcut"]?.string { widget.shortcut = v }
        if let v = table["status_command"]?.string { widget.statusCommand = v }
        if let v = table["status_interval_s"]?.int { widget.statusIntervalS = v }
        if let v = table["status_regex"]?.string { widget.statusRegex = v }
        if let v = table["command"]?.string { widget.command = v }
        if let v = table["cwd"]?.string { widget.cwd = v }
        if let v = table["autostart"]?.bool { widget.autostart = v }
        if let v = table["interval_s"]?.int { widget.intervalS = v }
        if let v = table["path"]?.string { widget.path = v }
        if let v = table["allow_shell"]?.bool { widget.allowShell = v }
        if let v = table["applescript"]?.string { widget.applescript = v }
        if let v = table["open_url"]?.string { widget.openUrl = v }

        if let buttonsArray = table["buttons"]?.array {
            widget.buttons = buttonsArray.compactMap { $0.table }.map(parseButton)
        }
        return widget
    }

    private static func parseButton(_ table: TOMLTable) -> WidgetButtonConfig {
        var button = WidgetButtonConfig()
        if let v = table["label"]?.string { button.label = v }
        if let v = table["command"]?.string { button.command = v }
        if let v = table["applescript"]?.string { button.applescript = v }
        if let v = table["open_url"]?.string { button.openUrl = v }
        return button
    }

    // MARK: - Helpers

    private static func extractLineNumber(from message: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"(?i)\bline\s+(\d+)\b"#),
              let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
              let range = Range(match.range(at: 1), in: message)
        else { return nil }
        return Int(message[range])
    }
}
