// ShelfManager.swift
// Manages pinned files and folders on the NotchDeck shelf.

import AppKit
import Combine
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.notchdeck.app", category: "ShelfManager")

@MainActor
final class ShelfManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var items: [ShelfItem] = []

    // MARK: - Paths

    let shelfDirectory: URL
    let filesDirectory: URL
    let metadataFile: URL
    private let fileManager = FileManager.default

    // MARK: - Init

    init(shelfDirectory: URL = ConfigManager.configDirectory.appendingPathComponent("shelf")) {
        self.shelfDirectory = shelfDirectory
        self.filesDirectory = shelfDirectory.appendingPathComponent("files")
        self.metadataFile = shelfDirectory.appendingPathComponent("shelf.json")

        ensureDirectoriesExist()
        loadItems()
    }

    private func ensureDirectoriesExist() {
        if !fileManager.fileExists(atPath: shelfDirectory.path) {
            try? fileManager.createDirectory(at: shelfDirectory, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: filesDirectory.path) {
            try? fileManager.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Persistence

    func loadItems() {
        guard fileManager.fileExists(atPath: metadataFile.path),
              let data = try? Data(contentsOf: metadataFile),
              let decoded = try? JSONDecoder().decode([ShelfItem].self, from: data) else {
            self.items = []
            return
        }
        self.items = decoded
        logger.debug("Loaded \(decoded.count) shelf items")
    }

    private func saveItems() {
        ensureDirectoriesExist()
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: metadataFile, options: .atomic)
            logger.debug("Saved \(self.items.count) shelf items")
        } catch {
            logger.error("Failed to save shelf items: \(error)")
        }
    }

    // MARK: - Add

    @discardableResult
    func addItem(from sourceURL: URL, copyOnDrop: Bool = false) -> ShelfItem? {
        ensureDirectoriesExist()

        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDir) else {
            logger.warning("File does not exist: \(sourceURL.path)")
            return nil
        }

        let name = sourceURL.lastPathComponent
        let isFolder = isDir.boolValue

        var finalPath = sourceURL.path
        var bookmarkData: Data? = nil
        var isCopied = false

        if copyOnDrop {
            let targetURL = filesDirectory.appendingPathComponent(name)
            // Remove existing destination if already there
            if fileManager.fileExists(atPath: targetURL.path) {
                try? fileManager.removeItem(at: targetURL)
            }
            do {
                try fileManager.copyItem(at: sourceURL, to: targetURL)
                finalPath = targetURL.path
                isCopied = true
                logger.info("Copied item to shelf: \(targetURL.path)")
            } catch {
                logger.error("Failed to copy item: \(error)")
                return nil
            }
        } else {
            // Security-scoped bookmark reference
            bookmarkData = try? sourceURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            logger.info("Pinned reference to: \(sourceURL.path)")
        }

        // Avoid duplicate paths
        if let existingIdx = items.firstIndex(where: { $0.path == finalPath }) {
            let updated = ShelfItem(
                id: items[existingIdx].id,
                name: name,
                path: finalPath,
                isFolder: isFolder,
                isCopied: isCopied,
                addedAt: Date(),
                bookmarkData: bookmarkData
            )
            items[existingIdx] = updated
            saveItems()
            return updated
        }

        let newItem = ShelfItem(
            name: name,
            path: finalPath,
            isFolder: isFolder,
            isCopied: isCopied,
            addedAt: Date(),
            bookmarkData: bookmarkData
        )

        items.insert(newItem, at: 0)
        saveItems()
        return newItem
    }

    // MARK: - Remove

    func removeItem(_ item: ShelfItem) {
        if item.isCopied {
            try? fileManager.removeItem(at: item.url)
        }
        items.removeAll { $0.id == item.id }
        saveItems()
        logger.info("Removed shelf item: \(item.name)")
    }

    // MARK: - Actions

    func openItem(_ item: ShelfItem) {
        NSWorkspace.shared.open(item.url)
    }

    func revealInFinder(_ item: ShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func copyPath(_ item: ShelfItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.path, forType: .string)
    }

    func airDropItem(_ item: ShelfItem) {
        if let service = NSSharingService(named: .sendViaAirDrop) {
            service.perform(withItems: [item.url])
        }
    }
}
