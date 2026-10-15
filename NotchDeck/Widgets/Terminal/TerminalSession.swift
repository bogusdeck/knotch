// TerminalSession.swift
// Encapsulates a persistent SwiftTerm terminal session.

import AppKit
import Foundation
import OSLog
import SwiftTerm

private let logger = Logger(subsystem: "com.notchdeck.app", category: "TerminalSession")

@MainActor
final class TerminalSession: NSObject, Identifiable, ObservableObject, LocalProcessTerminalViewDelegate {

    let id: String
    @Published var title: String
    let command: String?
    let cwd: String?
    let isServer: Bool

    @Published private(set) var isRunning: Bool = false
    @Published private(set) var exitCode: Int32? = nil

    private(set) var terminalView: LocalProcessTerminalView

    var onExit: ((TerminalSession, Int32?) -> Void)?

    init(
        id: String,
        title: String,
        command: String? = nil,
        cwd: String? = nil,
        isServer: Bool = false
    ) {
        self.id = id
        self.title = title
        self.command = command
        self.cwd = cwd
        self.isServer = isServer

        let view = LocalProcessTerminalView(frame: .zero)
        view.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        self.terminalView = view

        super.init()

        view.processDelegate = self
    }

    func start() {
        if isRunning { return }

        exitCode = nil
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        var args = ["-l"]

        if let command = command, !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args.append(contentsOf: ["-c", command])
        }

        let workingDir: String? = cwd.map { NSString(string: $0).expandingTildeInPath }

        logger.info("Starting terminal session '\(self.title)' (id: \(self.id)): \(shell) \(args) in \(workingDir ?? "home")")

        terminalView.startProcess(
            executable: shell,
            args: args,
            environment: nil,
            currentDirectory: workingDir
        )

        isRunning = true
    }

    func restart() {
        terminate()
        // Reset terminal buffer
        terminalView.feed(text: "\r\n[Restarting process...]\r\n")
        start()
    }

    func terminate() {
        if isRunning {
            terminalView.terminate()
            isRunning = false
        }
    }

    // MARK: - LocalProcessTerminalViewDelegate

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        if self.command == nil {
            self.title = title.isEmpty ? "zsh" : title
        }
    }

    func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}

    func processTerminated(source: SwiftTerm.TerminalView, exitCode: Int32?) {
        self.isRunning = false
        self.exitCode = exitCode
        logger.info("Terminal session '\(self.title)' exited with code: \(exitCode ?? -1)")
        self.onExit?(self, exitCode)
    }

    func processFailedToStart(source: SwiftTerm.TerminalView, error: LocalProcessError) {
        self.isRunning = false
        self.exitCode = -1
        logger.error("Terminal session '\(self.title)' failed to start: \(String(describing: error))")
        self.onExit?(self, -1)
    }
}
