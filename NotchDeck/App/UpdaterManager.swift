// UpdaterManager.swift
// Wrapper around Sparkle 2 for checking app updates.

import Foundation
import Sparkle
import OSLog

private let logger = Logger(subsystem: "com.notchdeck.app", category: "UpdaterManager")

@MainActor
final class UpdaterManager: ObservableObject {
    static let shared = UpdaterManager()

    private let updaterController: SPUStandardUpdaterController

    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }

    init() {
        // Initialize Sparkle standard updater controller
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        logger.info("UpdaterManager initialized")
    }

    func checkForUpdates() {
        logger.info("Checking for updates via Sparkle...")
        updaterController.checkForUpdates(nil)
    }
}
