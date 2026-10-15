// ConfigManager.swift
// Loads, validates, and watches ~/.config/notchdeck/config.toml.
// Hot-reloads on every save; keeps the last valid config if the new file has errors.

import AppKit
import Combine
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.notchdeck.app", category: "ConfigManager")

/// Manages the app-wide configuration, sourced from config.toml.
/// The file is the single source of truth; the Settings window reads and writes it directly.
@MainActor
final class ConfigManager: ObservableObject {

    // MARK: - Published state

    @Published private(set) var config: AppConfig = AppConfig()
    /// Non-nil when the current file has a parse or I/O error.
    @Published private(set) var configError: ConfigError? = nil

    // MARK: - Paths

    static let configDirectory: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("notchdeck")
    }()

    static let configFile: URL = configDirectory
        .appendingPathComponent("config.toml")

    // MARK: - Private state

    private var watcher: ConfigWatcher?

    // MARK: - Init

    init() {
        createDirectoryStructureIfNeeded()
        load()
        startWatching()
    }

    // MARK: - Load

    /// Reads and parses config.toml; on error keeps the last valid config and publishes the error.
    func load() {
        let url = Self.configFile
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let parsed = try TOMLParser.parse(text)
            config = parsed
            configError = nil
            logger.info("Config loaded successfully")
        } catch let error as ConfigError {
            configError = error
            logger.warning("Config error: \(error.localizedDescription ?? "unknown")")
        } catch {
            configError = .ioError(error.localizedDescription)
            logger.error("Config I/O error: \(error)")
        }
    }

    // MARK: - Write and Save

    /// Writes the given TOML string back to disk (used by the Settings window).
    func writeRaw(_ toml: String) throws {
        try toml.write(to: Self.configFile, atomically: true, encoding: .utf8)
    }

    /// Serializes and writes the config struct to config.toml.
    func save(config: AppConfig) throws {
        let toml = TOMLSerializer.serialize(config)
        try writeRaw(toml)
        self.config = config
        self.configError = nil
        logger.info("Saved updated config to disk")
    }

    func openConfigFileInDefaultEditor() {
        NSWorkspace.shared.open(Self.configFile)
    }

    func revealConfigFileInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Self.configFile])
    }

    // MARK: - FSEvents watcher

    private func startWatching() {
        watcher = ConfigWatcher(url: Self.configDirectory) { [weak self] in
            logger.debug("Config file changed — reloading")
            self?.load()
        }
        watcher?.start()
    }

    // MARK: - Directory scaffold

    private func createDirectoryStructureIfNeeded() {
        let fm = FileManager.default
        let dirs: [URL] = [
            Self.configDirectory,
            Self.configDirectory.appendingPathComponent("notes"),
            Self.configDirectory.appendingPathComponent("shelf"),
            Self.configDirectory.appendingPathComponent("widgets"),
            Self.configDirectory.appendingPathComponent("themes"),
        ]
        for dir in dirs {
            guard !fm.fileExists(atPath: dir.path) else { continue }
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                logger.info("Created directory: \(dir.path)")
            } catch {
                logger.error("Failed to create directory \(dir.path): \(error)")
            }
        }
        if !fm.fileExists(atPath: Self.configFile.path) {
            writeDefaultConfig()
        }
    }

    private func writeDefaultConfig() {
        do {
            try defaultConfigTOML.write(to: Self.configFile, atomically: true, encoding: .utf8)
            logger.info("Wrote default config.toml")
        } catch {
            logger.error("Failed to write default config: \(error)")
        }
    }
}

// MARK: - Config error type

enum ConfigError: LocalizedError, Sendable {
    case parseError(line: Int?, message: String)
    case ioError(String)

    var errorDescription: String? {
        switch self {
        case .parseError(let line, let msg):
            if let line { return "Config error at line \(line): \(msg)" }
            return "Config error: \(msg)"
        case .ioError(let msg):
            return "Config I/O error: \(msg)"
        }
    }
}

// MARK: - Default config content

let defaultConfigTOML = """
# NotchDeck Configuration
# Full reference: ~/.config/notchdeck/README → docs/CONFIG.md

[general]
screen = "builtin"
hover_to_peek = true
peek_delay_ms = 150
launch_at_login = false

[shortcuts]
toggle = "cmd+shift+space"
quick_note = "cmd+shift+n"

[appearance]
theme = "dark"
accent = "#7C5CFF"
expanded_width = 640
expanded_height = 260
corner_radius = 22

[layout]
tabs = ["home", "notes", "shelf", "terminal", "vpn"]
home = ["media", "clock", "calendar", "vpn-status"]

# ── Widget definitions ────────────────────────────────────────────────────
# Uncomment and edit to add widgets.

# [[widgets]]
# id = "vpn-status"
# type = "action"
# title = "Windscribe"
# icon = "lock.shield"
# status_command = "windscribe-cli status"
# status_interval_s = 10
# status_regex = "Connected"
# [[widgets.buttons]]
# label = "Connect"
# command = "windscribe-cli connect"
# [[widgets.buttons]]
# label = "Disconnect"
# command = "windscribe-cli disconnect"
"""
