// ShellWidgetTests.swift
// Unit tests for ShellWidget.

import XCTest
@testable import NotchDeck

@MainActor
final class ShellWidgetTests: XCTestCase {

    func testShellWidgetExecution() async {
        let widget = ShellWidget(
            id: "disk-check",
            title: "Disk Space",
            command: "echo 'Disk: 80% free'",
            interval: 60
        )

        await widget.executeCommand()

        XCTAssertEqual(widget.output, "Disk: 80% free")
        XCTAssertFalse(widget.hasError)
        XCTAssertNotNil(widget.lastUpdated)
    }

    func testShellWidgetErrorHandling() async {
        let widget = ShellWidget(
            id: "bad-cmd",
            title: "Bad Command",
            command: "non_existent_command_12345",
            interval: 60
        )

        await widget.executeCommand()

        XCTAssertTrue(widget.hasError)
    }
}
