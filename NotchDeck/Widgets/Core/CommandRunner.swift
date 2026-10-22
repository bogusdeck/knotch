// CommandRunner.swift
// Asynchronous, non-blocking process and script executor with timeout support.

import AppKit
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.notchdeck.app", category: "CommandRunner")

struct CommandResult: Sendable, Equatable {
    let stdout: String
    let stderr: String
    let exitCode: Int32

    var isSuccess: Bool {
        exitCode == 0
    }
}

enum CommandError: LocalizedError, Sendable {
    case timeout(seconds: TimeInterval)
    case processError(String)
    case invalidCommand

    var errorDescription: String? {
        switch self {
        case .timeout(let s):
            return "Command timed out after \(s)s"
        case .processError(let msg):
            return "Process error: \(msg)"
        case .invalidCommand:
            return "Invalid command"
        }
    }
}

enum CommandRunner {

    // MARK: - Run Shell Command

    /// Runs a command string asynchronously via the user's login shell or /bin/zsh with a timeout.
    /// Never blocks the calling thread.
    static func run(
        _ command: String,
        cwd: String? = nil,
        timeout: TimeInterval = 10.0
    ) async throws -> CommandResult {
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CommandError.invalidCommand
        }

        return try await withThrowingTaskGroup(of: CommandResult.self) { group in
            // Task 1: Process execution
            group.addTask {
                let process = Process()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()

                // Use login shell environment
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-l", "-c", command]

                if let cwd, !cwd.isEmpty {
                    let expandedPath = (cwd as NSString).expandingTildeInPath
                    process.currentDirectoryURL = URL(fileURLWithPath: expandedPath)
                }

                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    throw CommandError.processError(error.localizedDescription)
                }

                // Read output concurrently before waitUntilExit to avoid pipe buffer deadlock
                let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                process.waitUntilExit()

                let stdoutStr = String(data: outData, encoding: .utf8) ?? ""
                let stderrStr = String(data: errData, encoding: .utf8) ?? ""

                return CommandResult(
                    stdout: stdoutStr.trimmingCharacters(in: .newlines),
                    stderr: stderrStr.trimmingCharacters(in: .newlines),
                    exitCode: process.terminationStatus
                )
            }

            // Task 2: Timeout watchdog
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw CommandError.timeout(seconds: timeout)
            }

            // Return first completed, cancel others
            guard let result = try await group.next() else {
                throw CommandError.processError("Process failed to produce result")
            }
            group.cancelAll()
            return result
        }
    }

    // MARK: - Run AppleScript

    /// Executes an AppleScript string asynchronously.
    /// Attempts in-process NSAppleScript first, then falls back to /usr/bin/osascript process
    /// to avoid AppleEvents permission deadlocks and sandbox restrictions.
    @MainActor
    static func runAppleScript(_ scriptText: String) async throws -> String {
        guard !scriptText.isEmpty else { return "" }

        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    var errorDict: NSDictionary?
                    let script = NSAppleScript(source: scriptText)
                    let descriptor = script?.executeAndReturnError(&errorDict)

                    if let errorDict {
                        let message = errorDict[NSAppleScript.errorMessage] as? String ?? "AppleScript error"
                        continuation.resume(throwing: CommandError.processError(message))
                    } else {
                        let resultString = descriptor?.stringValue ?? ""
                        continuation.resume(returning: resultString)
                    }
                }
            }
            if !result.isEmpty {
                return result
            }
        } catch {
            logger.debug("NSAppleScript execution failed: \(error.localizedDescription), trying osascript fallback")
        }

        // Subprocess fallback via /usr/bin/osascript
        let process = Process()
        let stdoutPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", scriptText]
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()

        do {
            try process.run()
            let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return (String(data: outData, encoding: .utf8) ?? "").trimmingCharacters(in: .newlines)
            }
        } catch {
            logger.error("osascript fallback failed: \(error.localizedDescription)")
        }

        return ""
    }

    // MARK: - Open URL

    /// Opens a custom URL scheme (e.g. "spotify://...", "docker://...")
    @MainActor
    static func openURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return NSWorkspace.shared.open(url)
    }
}
