// HolderItem.swift
// Model representing an application, PDF, document, or folder pinned in the Holder tab.

import AppKit
import Foundation
import UniformTypeIdentifiers

enum HolderItemKind: String, Codable, Sendable {
    case application
    case pdf
    case folder
    case image
    case document
    case other

    static func detect(url: URL, isDirectory: Bool) -> HolderItemKind {
        let pathExtension = url.pathExtension.lowercased()
        if pathExtension == "app" || (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType?.conforms(to: .application)) == true {
            return .application
        }
        if pathExtension == "pdf" {
            return .pdf
        }
        if isDirectory {
            return .folder
        }
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "svg", "heic", "tiff", "bmp", "ico"]
        if imageExtensions.contains(pathExtension) {
            return .image
        }
        let docExtensions = ["txt", "md", "markdown", "json", "toml", "yaml", "yml", "csv", "docx", "pages", "numbers", "xlsx"]
        if docExtensions.contains(pathExtension) {
            return .document
        }
        return .other
    }
}

struct HolderItem: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let name: String
    let path: String
    let kind: HolderItemKind
    let addedAt: Date
    var bookmarkData: Data?

    var url: URL {
        if let bookmarkData {
            var isStale = false
            if let resolved = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return resolved
            }
        }
        return URL(fileURLWithPath: path)
    }

    var isApplication: Bool {
        kind == .application || path.lowercased().hasSuffix(".app")
    }

    var isPDF: Bool {
        kind == .pdf || path.lowercased().hasSuffix(".pdf")
    }

    var isRunning: Bool {
        guard isApplication else { return false }
        if let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier {
            return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
        }
        return NSWorkspace.shared.runningApplications.contains { app in
            guard let bundleURL = app.bundleURL else { return false }
            return bundleURL.standardizedFileURL.path == url.standardizedFileURL.path
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        kind: HolderItemKind,
        addedAt: Date = Date(),
        bookmarkData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.kind = kind
        self.addedAt = addedAt
        self.bookmarkData = bookmarkData
    }
}
