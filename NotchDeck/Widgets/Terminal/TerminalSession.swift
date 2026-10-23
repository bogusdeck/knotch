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

        let view = LocalProcessTerminalView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
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

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let workingDir: String = {
            if let cwd = cwd, !cwd.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return NSString(string: cwd).expandingTildeInPath
            }
            return homeDir
        }()

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["LANG"] = "en_US.UTF-8"
        let localBin = "\(homeDir)/.local/bin"
        let goBin = "\(homeDir)/go/bin"
        let standardPaths = [localBin, goBin, "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        if let currentPath = env["PATH"] {
            var parts = currentPath.split(separator: ":").map(String.init)
            for p in standardPaths.reversed() where !parts.contains(p) {
                parts.insert(p, at: 0)
            }
            env["PATH"] = parts.joined(separator: ":")
        } else {
            env["PATH"] = standardPaths.joined(separator: ":")
        }
        let envList = env.map { "\($0.key)=\($0.value)" }

        logger.info("Starting terminal session '\(self.title)' (id: \(self.id)): \(shell) \(args) in \(workingDir)")

        terminalView.startProcess(
            executable: shell,
            args: args,
            environment: envList,
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
