// HolderManager.swift
// Manages pinned applications, PDFs, and files for the Holder tab.

import AppKit
import Combine
import Foundation
import OSLog
import UniformTypeIdentifiers

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

        let targetURL = sourceURL.standardizedFileURL.resolvingSymlinksInPath()
        let resolvedPath = targetURL.path

        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: resolvedPath, isDirectory: &isDir) else {
            logger.warning("Item does not exist: \(resolvedPath)")
            return nil
        }

        let rawName = targetURL.lastPathComponent
        let displayName: String
        if rawName.hasSuffix(".app") {
            displayName = String(rawName.dropLast(4))
        } else {
            displayName = rawName
        }

        let kind = HolderItemKind.detect(url: targetURL, isDirectory: isDir.boolValue)

        // If item already exists with same path or name, return it
        if let existing = items.first(where: { $0.path == resolvedPath }) {
            return existing
        }

        let bookmarkData = try? targetURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let item = HolderItem(
            name: displayName,
            path: resolvedPath,
            kind: kind,
            bookmarkData: bookmarkData
        )

        items.append(item)
        saveItems()
        logger.info("Added item to holder: \(displayName) (\(kind.rawValue)) at \(resolvedPath)")
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

// MARK: - Drop URL Helper

@MainActor
enum DropURLHelper {

    static let supportedDropTypes: [UTType] = [
        .applicationBundle,
        .application,
        .fileURL,
        .item,
        .content,
        .data
    ]

    static func extractURLs(from providers: [NSItemProvider], completion: @escaping @MainActor ([URL]) -> Void) {
        // Fast path: Check active drag pasteboard first (always populated when dragging files/apps in macOS)
        if let dragURLs = NSPasteboard(name: .drag).readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !dragURLs.isEmpty {
            completion(dragURLs)
            return
        }

        Task { @MainActor in
            var results: [URL] = []
            for provider in providers {
                if let url = await extractSingleURLAsync(from: provider) {
                    results.append(url)
                }
            }
            completion(results)
        }
    }

    private static func extractSingleURLAsync(from provider: NSItemProvider) async -> URL? {
        let candidateTypes = [
            UTType.applicationBundle.identifier,
            UTType.application.identifier,
            UTType.fileURL.identifier,
            "public.file-url",
            UTType.item.identifier
        ]

        for typeId in candidateTypes {
            if provider.hasItemConformingToTypeIdentifier(typeId) {
                let url: URL? = await withCheckedContinuation { continuation in
                    provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, _ in
                        continuation.resume(returning: resolveItemToURL(item))
                    }
                }
                if let url {
                    return url
                }
            }
        }

        if provider.canLoadObject(ofClass: URL.self) {
            let url: URL? = await withCheckedContinuation { continuation in
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    continuation.resume(returning: url)
                }
            }
            if let url {
                return url
            }
        }

        return nil
    }

    private nonisolated static func resolveItemToURL(_ item: Any?) -> URL? {
        guard let item else { return nil }
        if let url = item as? URL {
            return url
        }
        if let data = item as? Data {
            if let url = URL(dataRepresentation: data, relativeTo: nil) {
                return url
            }
            if let string = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                if string.hasPrefix("file://"), let url = URL(string: string) {
                    return url
                }
                if FileManager.default.fileExists(atPath: string) {
                    return URL(fileURLWithPath: string)
                }
            }
        }
        if let string = item as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("file://"), let url = URL(string: trimmed) {
                return url
            }
            if FileManager.default.fileExists(atPath: trimmed) {
                return URL(fileURLWithPath: trimmed)
            }
        }
        return nil
    }
}
