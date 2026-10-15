// ShortcutParserTests.swift
// Unit tests for ShortcutParser string to KeyboardShortcuts.Shortcut conversion.

import XCTest
@testable import NotchDeck
import KeyboardShortcuts

@MainActor
final class ShortcutParserTests: XCTestCase {

    func testParseCmdShiftSpace() {
        let shortcut = ShortcutParser.parse("cmd+shift+space")
        XCTAssertNotNil(shortcut)
        XCTAssertEqual(shortcut?.key, .space)
        XCTAssertTrue(shortcut?.modifiers.contains(.command) ?? false)
        XCTAssertTrue(shortcut?.modifiers.contains(.shift) ?? false)
    }

    func testParseQuickNoteShortcut() {
        let shortcut = ShortcutParser.parse("cmd+shift+n")
        XCTAssertNotNil(shortcut)
        XCTAssertEqual(shortcut?.key, .n)
        XCTAssertTrue(shortcut?.modifiers.contains(.command) ?? false)
        XCTAssertTrue(shortcut?.modifiers.contains(.shift) ?? false)
    }

    func testParseCtrlOptT() {
        let shortcut = ShortcutParser.parse("ctrl+opt+t")
        XCTAssertNotNil(shortcut)
        XCTAssertEqual(shortcut?.key, .t)
        XCTAssertTrue(shortcut?.modifiers.contains(.control) ?? false)
        XCTAssertTrue(shortcut?.modifiers.contains(.option) ?? false)
    }

    func testParseFKey() {
        let shortcut = ShortcutParser.parse("cmd+f12")
        XCTAssertNotNil(shortcut)
        XCTAssertEqual(shortcut?.key, .f12)
        XCTAssertTrue(shortcut?.modifiers.contains(.command) ?? false)
    }

    func testParseInvalidShortcutReturnsNil() {
        XCTAssertNil(ShortcutParser.parse(""))
        XCTAssertNil(ShortcutParser.parse("cmd+shift")) // Missing key
        XCTAssertNil(ShortcutParser.parse("unknownkey"))
    }
}
