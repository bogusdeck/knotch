// TOMLSerializer.swift
// Serializes AppConfig back into a formatted TOML string.

import Foundation

enum TOMLSerializer {

    static func serialize(_ config: AppConfig) -> String {
        var lines: [String] = []

        lines.append("# NotchDeck Configuration")
        lines.append("# Sourced from ~/.config/notchdeck/config.toml")
        lines.append("")

        // [general]
        lines.append("[general]")
        lines.append("screen = \"\(escape(config.general.screen))\"")
        lines.append("hover_to_peek = \(config.general.hoverToPeek)")
        lines.append("peek_delay_ms = \(config.general.peekDelayMs)")
        lines.append("launch_at_login = \(config.general.launchAtLogin)")
        lines.append("copy_on_drop = \(config.general.copyOnDrop)")
        lines.append("")

        // [shortcuts]
        lines.append("[shortcuts]")
        lines.append("toggle = \"\(escape(config.shortcuts.toggle))\"")
        lines.append("quick_note = \"\(escape(config.shortcuts.quickNote))\"")
        lines.append("")

        // [appearance]
        lines.append("[appearance]")
        lines.append("theme = \"\(escape(config.appearance.theme))\"")
        lines.append("accent = \"\(escape(config.appearance.accent))\"")
        lines.append("expanded_width = \(config.appearance.expandedWidth)")
        lines.append("expanded_height = \(config.appearance.expandedHeight)")
        lines.append("corner_radius = \(config.appearance.cornerRadius)")
        lines.append("")

        // [layout]
        lines.append("[layout]")
        let tabsJoined = config.layout.tabs.map { "\"\($0)\"" }.joined(separator: ", ")
        lines.append("tabs = [\(tabsJoined)]")
        let homeJoined = config.layout.home.map { "\"\($0)\"" }.joined(separator: ", ")
        lines.append("home = [\(homeJoined)]")
        lines.append("")

        // [[widgets]]
        for widget in config.widgets {
            lines.append("[[widgets]]")
            lines.append("id = \"\(escape(widget.id))\"")
            lines.append("type = \"\(escape(widget.type))\"")
            lines.append("title = \"\(escape(widget.title))\"")
            if let icon = widget.icon {
                lines.append("icon = \"\(escape(icon))\"")
            }
            if let shortcut = widget.shortcut {
                lines.append("shortcut = \"\(escape(shortcut))\"")
            }
            if let statusCmd = widget.statusCommand {
                lines.append("status_command = \"\(escape(statusCmd))\"")
                lines.append("status_interval_s = \(widget.statusIntervalS)")
            }
            if let statusRegex = widget.statusRegex {
                lines.append("status_regex = \"\(escape(statusRegex))\"")
            }
            if let cmd = widget.command {
                lines.append("command = \"\(escape(cmd))\"")
            }
            if let cwd = widget.cwd {
                lines.append("cwd = \"\(escape(cwd))\"")
            }
            if widget.type == "terminal" {
                lines.append("autostart = \(widget.autostart)")
            }
            if widget.type == "shell" {
                lines.append("interval_s = \(widget.intervalS)")
            }
            if let path = widget.path {
                lines.append("path = \"\(escape(path))\"")
                lines.append("allow_shell = \(widget.allowShell)")
            }
            if let applescript = widget.applescript {
                lines.append("applescript = \"\(escape(applescript))\"")
            }
            if let openUrl = widget.openUrl {
                lines.append("open_url = \"\(escape(openUrl))\"")
            }

            for button in widget.buttons {
                lines.append("[[widgets.buttons]]")
                lines.append("label = \"\(escape(button.label))\"")
                if let cmd = button.command {
                    lines.append("command = \"\(escape(cmd))\"")
                }
                if let script = button.applescript {
                    lines.append("applescript = \"\(escape(script))\"")
                }
                if let url = button.openUrl {
                    lines.append("open_url = \"\(escape(url))\"")
                }
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private static func escape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
