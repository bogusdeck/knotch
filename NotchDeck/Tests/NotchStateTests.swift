// NotchStateTests.swift
// Unit tests for NotchState transitions and animatable value mapping.

import XCTest
@testable import NotchDeck

final class NotchStateTests: XCTestCase {

    func testAnimatableValues() {
        XCTAssertEqual(NotchState.collapsed.animatableValue, 0.0)
        XCTAssertEqual(NotchState.peek.animatableValue,      0.5)
        XCTAssertEqual(NotchState.expanded.animatableValue,  1.0)
    }

    func testIsVisible() {
        XCTAssertFalse(NotchState.collapsed.isVisible)
        XCTAssertTrue(NotchState.peek.isVisible)
        XCTAssertTrue(NotchState.expanded.isVisible)
    }

    func testEquality() {
        XCTAssertEqual(NotchState.collapsed, NotchState.collapsed)
        XCTAssertNotEqual(NotchState.collapsed, NotchState.expanded)
    }
}
