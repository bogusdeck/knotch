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
    var webCompanionURL: URL? {
        let lower = name.lowercased()
        if lower.contains("whatsapp") {
            return URL(string: "https://web.whatsapp.com")
        }
        if lower.contains("spotify") {
            return URL(string: "https://open.spotify.com")
        }
        if lower.contains("chatgpt") {
            return URL(string: "https://chatgpt.com")
        }
        if lower.contains("claude") {
            return URL(string: "https://claude.ai")
        }
        if lower.contains("notion") {
            return URL(string: "https://www.notion.so")
        }
        if lower.contains("discord") {
            return URL(string: "https://discord.com/app")
        }
        if lower.contains("slack") {
            return URL(string: "https://slack.com/signin")
        }
        if lower.contains("telegram") {
            return URL(string: "https://web.telegram.org/a/")
        }
        if lower.contains("twitter") || lower == "x" {
            return URL(string: "https://x.com")
        }
        if lower.contains("youtube") {
            return URL(string: "https://www.youtube.com")
        }
        if lower.contains("github") {
            return URL(string: "https://github.com")
        }
        if lower.contains("linear") {
            return URL(string: "https://linear.app")
        }
        if lower.contains("figma") {
            return URL(string: "https://www.figma.com")
        }
        if lower.contains("reddit") {
            return URL(string: "https://www.reddit.com")
        }
        if lower.contains("gmail") {
            return URL(string: "https://mail.google.com")
        }
        if lower.contains("calendar") {
            return URL(string: "https://calendar.google.com")
        }
        if lower.contains("jira") {
            return URL(string: "https://jira.atlassian.com")
        }
        if lower.contains("asana") {
            return URL(string: "https://app.asana.com")
        }
        if lower.contains("trello") {
            return URL(string: "https://trello.com")
        }
        if lower.contains("teams") {
            return URL(string: "https://teams.microsoft.com")
        }
        if lower.contains("zoom") {
            return URL(string: "https://zoom.us")
        }
        return nil
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
