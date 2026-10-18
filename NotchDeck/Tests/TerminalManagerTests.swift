// TerminalManagerTests.swift
// Tests for TerminalSession and TerminalManager.

import XCTest
@testable import NotchDeck

@MainActor
final class TerminalManagerTests: XCTestCase {

    func testInitialDefaultSession() {
        let manager = TerminalManager()
        XCTAssertFalse(manager.sessions.isEmpty)
        XCTAssertEqual(manager.sessions.first?.id, "default")
        XCTAssertEqual(manager.sessions.first?.title, "Shell")
        XCTAssertFalse(manager.sessions.first?.isServer ?? true)
    }

    func testCreateNewShellSession() {
        let manager = TerminalManager()
        let initialCount = manager.sessions.count
        manager.createNewShellSession()

        XCTAssertEqual(manager.sessions.count, initialCount + 1)
        let lastSession = manager.sessions.last
        XCTAssertNotNil(lastSession)
        XCTAssertTrue(lastSession?.id.starts(with: "shell_") ?? false)
        XCTAssertEqual(manager.selectedSessionId, lastSession?.id)
    }

    func testSyncConfiguredSessions() {
        let manager = TerminalManager()
        let configs = [
            WidgetConfig(
                id: "dev-server",
                type: "terminal",
                title: "Next.js",
                command: "npm run dev",
                cwd: "~/projects/app",
                autostart: false
            )
        ]

        manager.syncConfiguredSessions(widgets: configs)
        let session = manager.sessions.first { $0.id == "dev-server" }
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.title, "Next.js")
        XCTAssertEqual(session?.command, "npm run dev")
        XCTAssertTrue(session?.isServer ?? false)
    }

    func testCloseSession() {
        let manager = TerminalManager()
        manager.createNewShellSession()
        let newSessionId = manager.selectedSessionId

        XCTAssertTrue(manager.sessions.contains { $0.id == newSessionId })
        manager.closeSession(id: newSessionId)
        XCTAssertFalse(manager.sessions.contains { $0.id == newSessionId })

        // Default session should never be closed
        manager.closeSession(id: "default")
        XCTAssertTrue(manager.sessions.contains { $0.id == "default" })
    }

    func testTerminalContainerResizesTerminalView() {
        let session = TerminalSession(id: "test", title: "Test")
        let container = TerminalContainerView()
        container.setTerminalView(session.terminalView)
        container.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        XCTAssertEqual(session.terminalView.frame.size.width, 800)
        XCTAssertEqual(session.terminalView.frame.size.height, 600)
    }
}
