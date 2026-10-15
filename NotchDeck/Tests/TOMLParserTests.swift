// TOMLParserTests.swift
// Unit tests for TOMLParser, TOMLSerializer, and config error line detection.

import XCTest
@testable import NotchDeck

@MainActor
final class TOMLParserTests: XCTestCase {

    let sampleTOML = """
    [general]
    screen = "builtin"
    hover_to_peek = true
    peek_delay_ms = 150
    launch_at_login = true

    [shortcuts]
    toggle = "cmd+shift+space"
    quick_note = "cmd+shift+n"

    [appearance]
    theme = "dark"
    accent = "#7C5CFF"
    expanded_width = 640
    expanded_height = 260
    corner_radius = 22

    [layout]
    tabs = ["home", "notes", "shelf", "terminal", "vpn"]
    home = ["media", "clock", "calendar", "vpn-status"]

    [[widgets]]
    id = "vpn-status"
    type = "action"
    title = "Windscribe"
    icon = "lock.shield"
    status_command = "windscribe-cli status"
    status_interval_s = 10
    status_regex = "Connected"
    [[widgets.buttons]]
    label = "Connect"
    command = "windscribe-cli connect"
    [[widgets.buttons]]
    label = "Disconnect"
    command = "windscribe-cli disconnect"

    [[widgets]]
    id = "dev-server"
    type = "terminal"
    title = "Next.js"
    cwd = "~/projects/my-app"
    command = "npm run dev"
    autostart = false

    [[widgets]]
    id = "crypto"
    type = "web"
    path = "widgets/crypto"
    """

    func testParseCompleteConfig() throws {
        let config = try TOMLParser.parse(sampleTOML)

        // General
        XCTAssertEqual(config.general.screen, "builtin")
        XCTAssertTrue(config.general.hoverToPeek)
        XCTAssertEqual(config.general.peekDelayMs, 150)
        XCTAssertTrue(config.general.launchAtLogin)

        // Shortcuts
        XCTAssertEqual(config.shortcuts.toggle, "cmd+shift+space")
        XCTAssertEqual(config.shortcuts.quickNote, "cmd+shift+n")

        // Appearance
        XCTAssertEqual(config.appearance.theme, "dark")
        XCTAssertEqual(config.appearance.accent, "#7C5CFF")
        XCTAssertEqual(config.appearance.expandedWidth, 640)
        XCTAssertEqual(config.appearance.expandedHeight, 260)
        XCTAssertEqual(config.appearance.cornerRadius, 22)

        // Layout
        XCTAssertEqual(config.layout.tabs, ["home", "notes", "shelf", "terminal", "vpn"])
        XCTAssertEqual(config.layout.home, ["media", "clock", "calendar", "vpn-status"])

        // Widgets
        XCTAssertEqual(config.widgets.count, 3)

        // Widget 0: action
        let w0 = config.widgets[0]
        XCTAssertEqual(w0.id, "vpn-status")
        XCTAssertEqual(w0.type, "action")
        XCTAssertEqual(w0.title, "Windscribe")
        XCTAssertEqual(w0.icon, "lock.shield")
        XCTAssertEqual(w0.statusCommand, "windscribe-cli status")
        XCTAssertEqual(w0.statusIntervalS, 10)
        XCTAssertEqual(w0.statusRegex, "Connected")
        XCTAssertEqual(w0.buttons.count, 2)
        XCTAssertEqual(w0.buttons[0].label, "Connect")
        XCTAssertEqual(w0.buttons[0].command, "windscribe-cli connect")
        XCTAssertEqual(w0.buttons[1].label, "Disconnect")
        XCTAssertEqual(w0.buttons[1].command, "windscribe-cli disconnect")

        // Widget 1: terminal
        let w1 = config.widgets[1]
        XCTAssertEqual(w1.id, "dev-server")
        XCTAssertEqual(w1.type, "terminal")
        XCTAssertEqual(w1.cwd, "~/projects/my-app")
        XCTAssertEqual(w1.command, "npm run dev")
        XCTAssertFalse(w1.autostart)

        // Widget 2: web
        let w2 = config.widgets[2]
        XCTAssertEqual(w2.id, "crypto")
        XCTAssertEqual(w2.type, "web")
        XCTAssertEqual(w2.path, "widgets/crypto")
    }

    func testParsePartialConfigFallsBackToDefaults() throws {
        let partialTOML = """
        [appearance]
        theme = "light"
        accent = "#FF0000"
        """

        let config = try TOMLParser.parse(partialTOML)
        XCTAssertEqual(config.appearance.theme, "light")
        XCTAssertEqual(config.appearance.accent, "#FF0000")
        // Default general retained
        XCTAssertEqual(config.general.screen, "builtin")
        XCTAssertEqual(config.general.peekDelayMs, 150)
        // Default shortcuts retained
        XCTAssertEqual(config.shortcuts.toggle, "cmd+shift+space")
    }

    func testParseErrorWithLineNumber() {
        let brokenTOML = """
        [general]
        screen = "builtin"

        [appearance
        theme = "dark"
        """

        XCTAssertThrowsError(try TOMLParser.parse(brokenTOML)) { error in
            guard let configError = error as? ConfigError else {
                XCTFail("Expected ConfigError, got \(error)")
                return
            }
            switch configError {
            case .parseError(let line, _):
                XCTAssertNotNil(line, "Line number should be detected")
                XCTAssertEqual(line, 4, "Error should be detected at or around line 4")
            default:
                XCTFail("Expected parseError, got \(configError)")
            }
        }
    }

    func testSerializationRoundTrip() throws {
        let originalConfig = try TOMLParser.parse(sampleTOML)
        let serializedTOML = TOMLSerializer.serialize(originalConfig)
        let reparsedConfig = try TOMLParser.parse(serializedTOML)

        XCTAssertEqual(originalConfig, reparsedConfig)
    }
}
