// NoteItem.swift
// Model representing a quick note stored as a .md file in ~/.config/notchdeck/notes/

import Foundation

/// Represents a parsed line inside a note for rendering interactive todos or normal text.
struct ParsedLineItem: Identifiable, Sendable, Equatable {
    let id: Int
    let isTodo: Bool
    let isCompleted: Bool
    let text: String
}

struct NoteItem: Identifiable, Sendable, Equatable {
    let id: String
    let filename: String
    let fileURL: URL
    var content: String
    var isPinned: Bool
    var createdAt: Date
    var modifiedAt: Date

    /// Derived title: first non-empty line stripped of markdown headers and todo prefixes, or "Untitled Note".
    var title: String {
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("---") { continue }
            var headerCleaned = trimmed.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
            headerCleaned = headerCleaned.replacingOccurrences(of: "^[-*+]?\\s*\\[[ xX]?\\]\\s*", with: "", options: .regularExpression)
            if !headerCleaned.isEmpty {
                return headerCleaned
            }
        }
        return "Untitled Note"
    }

    /// Whether this note contains any todo checkboxes ([ ], [x], [], etc.)
    var hasTodos: Bool {
        content.range(of: "(^|\\n)\\s*[-*+]?\\s*\\[[ xX]?\\]", options: .regularExpression) != nil
    }

    /// Count of completed and total todo items in the note
    var todoStats: (completed: Int, total: Int) {
        let lines = content.components(separatedBy: .newlines)
        var total = 0
        var completed = 0
        for line in lines {
            if line.range(of: "^\\s*[-*+]?\\s*\\[[xX]\\]", options: .regularExpression) != nil {
                total += 1
                completed += 1
            } else if line.range(of: "^\\s*[-*+]?\\s*\\[[ ]?\\]", options: .regularExpression) != nil {
                total += 1
            }
        }
        return (completed, total)
    }

    /// Parsed lines for rendering in note cards
    var parsedLines: [ParsedLineItem] {
        let lines = content.components(separatedBy: .newlines)
        var result: [ParsedLineItem] = []
        for (idx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("---") { continue }

            if let match = line.range(of: "^\\s*[-*+]?\\s*\\[[xX]\\]\\s*", options: .regularExpression) {
                let text = String(line[match.upperBound...])
                result.append(ParsedLineItem(id: idx, isTodo: true, isCompleted: true, text: text))
            } else if let match = line.range(of: "^\\s*[-*+]?\\s*\\[[ ]?\\]\\s*", options: .regularExpression) {
                let text = String(line[match.upperBound...])
                result.append(ParsedLineItem(id: idx, isTodo: true, isCompleted: false, text: text))
            } else if !trimmed.isEmpty {
                let headerCleaned = trimmed.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                result.append(ParsedLineItem(id: idx, isTodo: false, isCompleted: false, text: headerCleaned))
            }
        }
        return result
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

    /// Toggles the todo checkbox at the given line index.
    func togglingTodo(at lineIndex: Int) -> NoteItem {
        var lines = content.components(separatedBy: "\n")
        guard lineIndex >= 0 && lineIndex < lines.count else { return self }
        let line = lines[lineIndex]

        if let range = line.range(of: "\\[[xX]\\]", options: .regularExpression) {
            lines[lineIndex] = line.replacingCharacters(in: range, with: "[ ]")
        } else if let range = line.range(of: "\\[ \\]", options: .regularExpression) {
            lines[lineIndex] = line.replacingCharacters(in: range, with: "[x]")
        } else if let range = line.range(of: "\\[\\]", options: .regularExpression) {
            lines[lineIndex] = line.replacingCharacters(in: range, with: "[x]")
        }

        var updated = self
        updated.content = lines.joined(separator: "\n")
        updated.modifiedAt = Date()
        return updated
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
