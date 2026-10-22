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
    @Published var activeEmbeddedAppItem: HolderItem? = nil

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
        if activeEmbeddedAppItem?.id == item.id {
            activeEmbeddedAppItem = nil
        }
        items.removeAll { $0.id == item.id }
        saveItems()
        logger.info("Removed holder item: \(item.name)")
    }

    func launchOrOpenItem(_ item: HolderItem) {
        if item.webCompanionURL != nil {
            openEmbeddedApp(item)
        } else if item.isApplication {
            launchNativeApp(item)
        } else if item.isPDF {
            selectedItemForPreview = item
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    func openEmbeddedApp(_ item: HolderItem) {
        selectedItemForPreview = nil
        activeEmbeddedAppItem = item
        logger.info("Opening embedded web view for \(item.name)")
    }

    func closeEmbeddedApp() {
        activeEmbeddedAppItem = nil
        logger.info("Closed embedded web view")
    }

    func launchNativeApp(_ item: HolderItem) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: item.url, configuration: config) { app, error in
            if let error {
                logger.error("Failed to launch application \(item.name): \(error)")
                return
            }
            if let app {
                Task { @MainActor in
                    self.dockWindowToNotch(for: app)
                }
            }
        }
    }

    private func dockWindowToNotch(for app: NSRunningApplication) {
        // Try docking with multiple delays to accommodate both instant activation and cold-launch window creation
        for delay in [0.15, 0.5, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let appElement = AXUIElementCreateApplication(app.processIdentifier)
                var windowsRef: AnyObject?
                guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                      let windows = windowsRef as? [AXUIElement], let frontWindow = windows.first else {
                    return
                }

                let notchFrame = NotchGeometryDetector.detect().notchFrame

                var currentSize = CGSize.zero
                var sizeVal: AnyObject?
                if AXUIElementCopyAttributeValue(frontWindow, kAXSizeAttribute as CFString, &sizeVal) == .success,
                   let val = sizeVal as! AXValue? {
                    AXValueGetValue(val, .cgSize, &currentSize)
                }

                let winWidth = max(currentSize.width, 700)
                let targetX = notchFrame.midX - (winWidth / 2)
                let targetY = max(notchFrame.height + 6, 36)

                var newPoint = CGPoint(x: max(10, targetX), y: targetY)
                if let pointVal = AXValueCreate(.cgPoint, &newPoint) {
                    AXUIElementSetAttributeValue(frontWindow, kAXPositionAttribute as CFString, pointVal)
                }
            }
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
        let dragPb = NSPasteboard(name: .drag)

        // Fast path 1: Check active drag pasteboard objects
        if let dragURLs = dragPb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !dragURLs.isEmpty {
            completion(dragURLs)
            return
        }

        // Fast path 2: Check Dock-specific item plist on drag pasteboard
        let dockType = NSPasteboard.PasteboardType("com.apple.dock.item")
        if let dockPlist = (dragPb.propertyList(forType: dockType) as? [String: Any]) ??
           (dragPb.data(forType: dockType).flatMap { (try? PropertyListSerialization.propertyList(from: $0, format: nil)) as? [String: Any] }) {
            let target = (dockPlist["tile-data"] as? [String: Any]) ?? dockPlist
            if let fileData = target["file-data"] as? [String: Any],
               let urlString = fileData["_CFURLString"] as? String,
               let url = URL(string: urlString) {
                completion([url])
                return
            } else if let bundleId = target["bundle-identifier"] as? String,
                      let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                completion([appURL])
                return
            } else if let label = target["file-label"] as? String {
                let appURL = URL(fileURLWithPath: "/Applications/\(label).app")
                if FileManager.default.fileExists(atPath: appURL.path) {
                    completion([appURL])
                    return
                }
            }
        }

        // Fast path 3: Check NSFilenamesPboardType
        if let filenames = dragPb.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String], !filenames.isEmpty {
            let urls = filenames.map { URL(fileURLWithPath: $0) }
            completion(urls)
            return
        }

        // Fast path 4: Check string / file-url
        if let string = dragPb.string(forType: .string) {
            if string.hasPrefix("file://"), let url = URL(string: string) {
                completion([url])
                return
            } else if FileManager.default.fileExists(atPath: string) {
                completion([URL(fileURLWithPath: string)])
                return
            }
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
            "com.apple.dock.item",
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
        if let dockDict = item as? [String: Any] {
            let target = (dockDict["tile-data"] as? [String: Any]) ?? dockDict
            if let fileData = target["file-data"] as? [String: Any],
               let urlString = fileData["_CFURLString"] as? String,
               let url = URL(string: urlString) {
                return url
            }
            if let bundleId = target["bundle-identifier"] as? String,
               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                return appURL
            }
            if let label = target["file-label"] as? String {
                let appURL = URL(fileURLWithPath: "/Applications/\(label).app")
                if FileManager.default.fileExists(atPath: appURL.path) {
                    return appURL
                }
            }
        }
        if let data = item as? Data {
            if let plist = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] {
                let target = (plist["tile-data"] as? [String: Any]) ?? plist
                if let fileData = target["file-data"] as? [String: Any],
                   let urlString = fileData["_CFURLString"] as? String,
                   let url = URL(string: urlString) {
                    return url
                }
                if let bundleId = target["bundle-identifier"] as? String,
                   let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    return appURL
                }
                if let label = target["file-label"] as? String {
                    let appURL = URL(fileURLWithPath: "/Applications/\(label).app")
                    if FileManager.default.fileExists(atPath: appURL.path) {
                        return appURL
                    }
                }
            }
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
