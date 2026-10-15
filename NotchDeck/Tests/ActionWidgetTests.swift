// ActionWidgetTests.swift
// Unit tests for ActionWidget: status polling, regex matching, and button execution.

import XCTest
@testable import NotchDeck

@MainActor
final class ActionWidgetTests: XCTestCase {

    func testWindscribeActionWidgetConnectedMatch() async {
        var cfg = WidgetConfig()
        cfg.id = "vpn-status"
        cfg.type = "action"
        cfg.title = "Windscribe"
        cfg.statusCommand = "echo 'Status: Connected to US East'"
        cfg.statusRegex = "Connected"
        cfg.buttons = [
            WidgetButtonConfig(label: "Connect", command: "echo connect"),
            WidgetButtonConfig(label: "Disconnect", command: "echo disconnect")
        ]

        let widget = ActionWidget(config: cfg)
        await widget.pollStatus()

        XCTAssertEqual(widget.status, .active)
        XCTAssertTrue(widget.lastOutput.contains("Connected to US East"))
    }

    func testWindscribeActionWidgetDisconnectedMatch() async {
        var cfg = WidgetConfig()
        cfg.id = "vpn-status"
        cfg.type = "action"
        cfg.title = "Windscribe"
        cfg.statusCommand = "echo 'Status: Disconnected'"
        cfg.statusRegex = "Connected"

        let widget = ActionWidget(config: cfg)
        await widget.pollStatus()

        XCTAssertEqual(widget.status, .inactive)
        XCTAssertTrue(widget.lastOutput.contains("Disconnected"))
    }

    func testActionWidgetExitCodeBasedStatus() async {
        var cfg = WidgetConfig()
        cfg.id = "service-check"
        cfg.type = "action"
        cfg.title = "Service"
        cfg.statusCommand = "exit 0" // Success = active
        cfg.statusRegex = nil

        let widget = ActionWidget(config: cfg)
        await widget.pollStatus()

        XCTAssertEqual(widget.status, .active)
    }

    func testActionWidgetCommandFailureSetsErrorStatus() async {
        var cfg = WidgetConfig()
        cfg.id = "failing-cmd"
        cfg.type = "action"
        cfg.title = "Failing"
        cfg.statusCommand = "invalid_command_that_does_not_exist_xyz123"

        let widget = ActionWidget(config: cfg)
        await widget.pollStatus()

        switch widget.status {
        case .error, .inactive:
            break // Expected
        default:
            XCTFail("Status should be error or inactive, got \(widget.status)")
        }
    }
}
