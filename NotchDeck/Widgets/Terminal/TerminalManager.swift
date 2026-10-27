// TerminalManager.swift
// Manages active terminal sessions across NotchDeck.

import AppKit
import Foundation
import OSLog
import UserNotifications

private let logger = Logger(subsystem: "com.notchdeck.app", category: "TerminalManager")

@MainActor
final class TerminalManager: ObservableObject {
    static let shared = TerminalManager()

    @Published var sessions: [TerminalSession] = []
    @Published var selectedSessionId: String = "default"

    var hasRunningServers: Bool {
        sessions.contains { $0.isRunning && $0.isServer }
    }

    var activeSession: TerminalSession? {
        sessions.first(where: { $0.id == selectedSessionId }) ?? sessions.first
    }

    init() {
        // Create initial default shell session
        let defaultSession = TerminalSession(
            id: "default",
            title: "Shell",
            command: nil,
            cwd: nil,
            isServer: false
        )
        attachExitHandler(to: defaultSession)
        sessions.append(defaultSession)
        defaultSession.start()

        requestNotificationAuthorization()
    }

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                logger.warning("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    private func attachExitHandler(to session: TerminalSession) {
        session.onExit = { [weak self] exitingSession, code in
            guard let code = code, code != 0 else { return }
            self?.notifyExit(for: exitingSession, exitCode: code)
        }
    }

    private func notifyExit(for session: TerminalSession, exitCode: Int32) {
        let content = UNMutableNotificationContent()
        content.title = "Knotch Terminal"
        content.body = "Process '\(session.title)' exited with code \(exitCode)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "terminal_exit_\(session.id)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                logger.error("Failed to post exit notification: \(error.localizedDescription)")
            }
        }
    }

    /// Syncs preset terminal sessions defined in config.toml
    func syncConfiguredSessions(widgets: [WidgetConfig]) {
        let terminalWidgets = widgets.filter { $0.type == "terminal" }

        for widget in terminalWidgets {
            if let existing = sessions.first(where: { $0.id == widget.id }) {
                existing.title = widget.title
                continue
            }

            let session = TerminalSession(
                id: widget.id,
                title: widget.title.isEmpty ? widget.id : widget.title,
                command: widget.command,
                cwd: widget.cwd,
                isServer: true
            )
            attachExitHandler(to: session)
            sessions.append(session)

            if widget.autostart {
                session.start()
            }
        }
    }

    func createNewShellSession() {
        let newIndex = sessions.filter { $0.command == nil }.count + 1
        let id = "shell_\(UUID().uuidString.prefix(6))"
        let session = TerminalSession(
            id: id,
            title: "Shell \(newIndex)",
            command: nil,
            cwd: nil,
            isServer: false
        )
        attachExitHandler(to: session)
        sessions.append(session)
        selectedSessionId = id
        session.start()
    }

    func closeSession(id: String) {
        guard id != "default" else { return } // Keep default shell session
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            let session = sessions.remove(at: index)
            session.terminate()
            if selectedSessionId == id {
                selectedSessionId = sessions.first?.id ?? "default"
            }
        }
    }
}
