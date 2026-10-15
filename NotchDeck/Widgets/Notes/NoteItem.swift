// NoteItem.swift
// Model representing a quick note stored as a .md file in ~/.config/notchdeck/notes/

import Foundation

struct NoteItem: Identifiable, Sendable, Equatable {
    let id: String
    let filename: String
    let fileURL: URL
    var content: String
    var isPinned: Bool
    var createdAt: Date
    var modifiedAt: Date

    /// Derived title: first non-empty line stripped of markdown headers, or "Untitled Note".
    var title: String {
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("---") { continue }
            let headerCleaned = trimmed.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
            if !headerCleaned.isEmpty {
                return headerCleaned
            }
        }
        return "Untitled Note"
    }

    /// Derived preview: body text following the title.
    var preview: String {
        let lines = content.components(separatedBy: .newlines)
        var passedTitle = false
        var previewLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("---") { continue }
            if !passedTitle {
                passedTitle = true
                continue
            }
            previewLines.append(trimmed)
            if previewLines.count >= 2 { break }
        }
        return previewLines.joined(separator: " ")
    }

    // MARK: - Markdown Serialization

    /// Encodes note with standard YAML frontmatter for pinned status & timestamp.
    func serializeToMarkdown() -> String {
        let isoFormatter = ISO8601DateFormatter()
        let createdStr = isoFormatter.string(from: createdAt)
        let modifiedStr = isoFormatter.string(from: modifiedAt)

        return """
        ---
        pinned: \(isPinned)
        created: \(createdStr)
        modified: \(modifiedStr)
        ---
        \(content)
        """
    }

    /// Parses markdown file contents, extracting frontmatter if present.
    static func parse(from fileURL: URL, rawText: String, fileDates: (created: Date, modified: Date)) -> NoteItem {
        let id = fileURL.deletingPathExtension().lastPathComponent
        let filename = fileURL.lastPathComponent

        var isPinned = false
        var createdAt = fileDates.created
        var modifiedAt = fileDates.modified
        var bodyContent = rawText

        if rawText.hasPrefix("---") {
            let scanner = Scanner(string: rawText)
            _ = scanner.scanString("---")
            if let frontmatter = scanner.scanUpToString("---") {
                _ = scanner.scanString("---")
                bodyContent = scanner.string[scanner.currentIndex...].trimmingCharacters(in: .newlines)

                let lines = frontmatter.components(separatedBy: .newlines)
                let isoFormatter = ISO8601DateFormatter()

                for line in lines {
                    let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                    guard parts.count == 2 else { continue }
                    let key = parts[0].lowercased()
                    let value = parts[1]

                    if key == "pinned" {
                        isPinned = (value.lowercased() == "true")
                    } else if key == "created", let date = isoFormatter.date(from: value) {
                        createdAt = date
                    } else if key == "modified", let date = isoFormatter.date(from: value) {
                        modifiedAt = date
                    }
                }
            }
        }

        return NoteItem(
            id: id,
            filename: filename,
            fileURL: fileURL,
            content: bodyContent,
            isPinned: isPinned,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }
}
