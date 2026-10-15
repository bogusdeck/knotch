// ShelfItem.swift
// Model representing a pinned file or folder on the NotchDeck shelf.

import Foundation

struct ShelfItem: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let name: String
    let path: String
    let isFolder: Bool
    let isCopied: Bool
    let addedAt: Date
    var bookmarkData: Data?

    var url: URL {
        // Resolve security-scoped bookmark if present
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

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        isFolder: Bool,
        isCopied: Bool = false,
        addedAt: Date = Date(),
        bookmarkData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.isFolder = isFolder
        self.isCopied = isCopied
        self.addedAt = addedAt
        self.bookmarkData = bookmarkData
    }
}
