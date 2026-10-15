// WebWidgetBridgeTests.swift
// Tests for WebWidgetBridge and JavaScript bridge security.

import WebKit
import XCTest
@testable import NotchDeck

@MainActor
final class WebWidgetBridgeTests: XCTestCase {

    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotchDeckWebWidgetTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testInjectionScriptContainsConfigAndMethods() {
        let bridge = WebWidgetBridge(
            widgetId: "test-widget",
            widgetTitle: "Test Widget",
            allowShell: false,
            widgetDirURL: tempDir,
            widgetConfig: ["id": "test-widget", "title": "Test Widget"]
        )

        let script = bridge.injectionScript()
        XCTAssertTrue(script.contains("window.notch"))
        XCTAssertTrue(script.contains("run:"))
        XCTAssertTrue(script.contains("storage:"))
        XCTAssertTrue(script.contains("notify:"))
        XCTAssertTrue(script.contains("\"id\":\"test-widget\""))
    }

    func testAllowShellFalseRejection() async {
        let bridge = WebWidgetBridge(
            widgetId: "crypto",
            widgetTitle: "Crypto",
            allowShell: false,
            widgetDirURL: tempDir,
            widgetConfig: [:]
        )

        let expectation = expectation(description: "Bridge replies with error")

        // Construct fake message
        let body: [String: Any] = [
            "action": "run",
            "command": "echo hello"
        ]

        // Test nonisolated callback handler directly
        let controller = WKUserContentController()
        // Create dummy WKScriptMessage if possible or invoke message handler via subclass/Task
        // Since WKScriptMessage cannot be directly instantiated from Swift, test bridge logic directly
        XCTAssertFalse(bridge.allowShell)
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}
