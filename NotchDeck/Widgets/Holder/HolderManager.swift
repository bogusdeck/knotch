// HolderManager.swift
// Manages pinned applications, PDFs, and files for the Holder tab.

import AppKit
import Combine
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.notchdeck.app", category: "HolderManager")

@MainActor
final class HolderManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var items: [HolderItem] = []
    @Published var selectedItemForPreview: HolderItem? = nil

    // MARK: - Paths

    let holderDirectory: URL
    let metadataFile: URL
    private let fileManager = FileManager.default

    // MARK: - Init

    init(holderDirectory: URL = ConfigManager.configDirectory.appendingPathComponent("holder")) {
        self.holderDirectory = holderDirectory
        self.metadataFile = holderDirectory.appendingPathComponent("items.json")

        ensureDirectoryExists()
        loadItems()
    }

    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: holderDirectory.path) {
            try? fileManager.createDirectory(at: holderDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Persistence

    func loadItems() {
        guard fileManager.fileExists(atPath: metadataFile.path),
              let data = try? Data(contentsOf: metadataFile),
              let decoded = try? JSONDecoder().decode([HolderItem].self, from: data) else {
            self.items = []
            return
        }
        self.items = decoded
        logger.debug("Loaded \(decoded.count) holder items")
    }

    private func saveItems() {
        ensureDirectoryExists()
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: metadataFile, options: .atomic)
            logger.debug("Saved \(self.items.count) holder items")
        } catch {
            logger.error("Failed to save holder items: \(error)")
        }
    }

    // MARK: - Item Management

    @discardableResult
    func addItem(from sourceURL: URL) -> HolderItem? {
        ensureDirectoryExists()

        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDir) else {
            logger.warning("Item does not exist: \(sourceURL.path)")
            return nil
        }

        let rawName = sourceURL.lastPathComponent
        let displayName: String
        if rawName.hasSuffix(".app") {
            displayName = String(rawName.dropLast(4))
        } else {
            displayName = rawName
        }

        let kind = HolderItemKind.detect(url: sourceURL, isDirectory: isDir.boolValue)

        // If item already exists with same path, return it
        if let existing = items.first(where: { $0.path == sourceURL.path }) {
            return existing
        }

        let bookmarkData = try? sourceURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let item = HolderItem(
            name: displayName,
            path: sourceURL.path,
            kind: kind,
            bookmarkData: bookmarkData
        )

        items.append(item)
        saveItems()
        logger.info("Added item to holder: \(displayName) (\(kind.rawValue))")
        return item
    }

    func removeItem(_ item: HolderItem) {
        if selectedItemForPreview?.id == item.id {
            selectedItemForPreview = nil
        }
        items.removeAll { $0.id == item.id }
        saveItems()
        logger.info("Removed holder item: \(item.name)")
    }

    func launchOrOpenItem(_ item: HolderItem) {
        if item.isApplication {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: item.url, configuration: config) { _, error in
                if let error {
                    logger.error("Failed to launch application \(item.name): \(error)")
                }
            }
        } else if item.isPDF {
            selectedItemForPreview = item
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    func openExternal(_ item: HolderItem) {
        NSWorkspace.shared.open(item.url)
    }

    func previewItem(_ item: HolderItem) {
        selectedItemForPreview = item
    }

    func closePreview() {
        selectedItemForPreview = nil
    }

    func revealInFinder(_ item: HolderItem) {
        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
    }

    func copyPath(_ item: HolderItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.path, forType: .string)
    }
}
