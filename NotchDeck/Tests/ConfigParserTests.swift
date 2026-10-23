// ConfigParserTests.swift
// Unit tests for Phase 1 config defaults.
// Phase 2 will add TOML parsing tests.

import XCTest
@testable import NotchDeck

@MainActor
final class ConfigParserTests: XCTestCase {

    // MARK: - Default values

    func testDefaultGeneralConfig() {
        let cfg = AppConfig()
        XCTAssertEqual(cfg.general.screen, "builtin")
        XCTAssertTrue(cfg.general.hoverToPeek)
        XCTAssertEqual(cfg.general.peekDelayMs, 150)
        XCTAssertFalse(cfg.general.launchAtLogin)
    }

    func testDefaultAppearanceConfig() {
        let cfg = AppConfig()
        XCTAssertEqual(cfg.appearance.theme, "dark")
        XCTAssertEqual(cfg.appearance.accent, "#7C5CFF")
        XCTAssertEqual(cfg.appearance.expandedWidth, 640)
        XCTAssertEqual(cfg.appearance.expandedHeight, 260)
        XCTAssertEqual(cfg.appearance.cornerRadius, 22)
    }

    func testDefaultLayoutTabs() {
        let cfg = AppConfig()
        XCTAssertEqual(cfg.layout.tabs, LayoutConfig.default.tabs)
    }

    func testDefaultShortcuts() {
        let cfg = AppConfig()
        XCTAssertEqual(cfg.shortcuts.toggle, "cmd+shift+space")
        XCTAssertEqual(cfg.shortcuts.quickNote, "cmd+shift+n")
    }
}
