// WidgetRegistryTests.swift
// Unit tests for WidgetRegistry.

import XCTest
@testable import NotchDeck
import SwiftUI

@MainActor
final class WidgetRegistryTests: XCTestCase {

    private var registry: WidgetRegistry!

    override func setUp() {
        super.setUp()
        registry = WidgetRegistry()
    }

    // MARK: - Registration

    func testRegisterWidget() {
        let widget = StubWidget(id: "stub-1", title: "Stub")
        registry.register(widget)
        XCTAssertNotNil(registry.widget(id: "stub-1"))
        XCTAssertEqual(registry.widgets.count, 1)
    }

    func testRegisterReplacesExistingId() {
        registry.register(StubWidget(id: "w", title: "Original"))
        registry.register(StubWidget(id: "w", title: "Replacement"))
        XCTAssertEqual(registry.widgets.count, 1)
        XCTAssertEqual(registry.widget(id: "w")?.title, "Replacement")
    }

    func testUnregisterWidget() {
        registry.register(StubWidget(id: "w", title: "Test"))
        registry.unregister(id: "w")
        XCTAssertNil(registry.widget(id: "w"))
        XCTAssertEqual(registry.widgets.count, 0)
    }

    func testLookupMissingWidget() {
        XCTAssertNil(registry.widget(id: "nonexistent"))
    }
}

// MARK: - Test double

private struct StubWidget: NotchWidget {
    let id: String
    let title: String
    func compactView()  -> AnyView { AnyView(EmptyView()) }
    func expandedView() -> AnyView { AnyView(EmptyView()) }
}
