// NotesManager.swift
// Manages markdown note files in ~/.config/notchdeck/notes/

import AppKit
import Combine
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.notchdeck.app", category: "NotesManager")

enum NoteFilterCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case notes = "Notes"
    case todos = "Todos"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .notes: return "note.text"
        case .todos: return "checklist"
        }
    }
}

@MainActor
final class NotesManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var notes: [NoteItem] = []
    @Published var searchQuery: String = ""
    @Published var filterCategory: NoteFilterCategory = .all

    // MARK: - Properties

    let notesDirectory: URL
    private let fileManager = FileManager.default

    // MARK: - Init

    init(notesDirectory: URL = ConfigManager.configDirectory.appendingPathComponent("notes")) {
        self.notesDirectory = notesDirectory
        ensureDirectoryExists()
        loadNotes()
    }

    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: notesDirectory.path) {
            try? fileManager.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Load

    func loadNotes() {
        ensureDirectoryExists()
        do {
            let files = try fileManager.contentsOfDirectory(at: notesDirectory, includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey])
            let mdFiles = files.filter { $0.pathExtension.lowercased() == "md" }

            var loaded: [NoteItem] = []
            for url in mdFiles {
                guard let rawText = try? String(contentsOf: url, encoding: .utf8) else { continue }
                let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                let created = values?.creationDate ?? Date()
                let modified = values?.contentModificationDate ?? Date()

                let item = NoteItem.parse(from: url, rawText: rawText, fileDates: (created, modified))
                loaded.append(item)
            }

            self.notes = loaded
            logger.debug("Loaded \(loaded.count) notes from \(self.notesDirectory.path)")
        } catch {
            logger.error("Failed to load notes: \(error)")
        }
    }

    // MARK: - Create

    @discardableResult
    func createNote(content: String, isPinned: Bool = false) -> NoteItem? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        ensureDirectoryExists()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = formatter.string(from: Date())
        var filename = "note-\(timestamp).md"
        var targetURL = notesDirectory.appendingPathComponent(filename)

        // Ensure unique filename if created within the same second
        var counter = 1
        while fileManager.fileExists(atPath: targetURL.path) {
            filename = "note-\(timestamp)-\(counter).md"
            targetURL = notesDirectory.appendingPathComponent(filename)
            counter += 1
        }

        let now = Date()
        let note = NoteItem(
            id: targetURL.deletingPathExtension().lastPathComponent,
            filename: filename,
            fileURL: targetURL,
            content: trimmed,
            isPinned: isPinned,
            createdAt: now,
            modifiedAt: now
        )

        let serialized = note.serializeToMarkdown()
        do {
            try serialized.write(to: targetURL, atomically: true, encoding: .utf8)
            notes.insert(note, at: 0)
            logger.info("Created note: \(filename)")
            return note
        } catch {
            logger.error("Failed to write note file: \(error)")
            return nil
        }
    }

    // MARK: - Save / Update

    func saveNote(_ note: NoteItem) {
        let serialized = note.serializeToMarkdown()
        do {
            try serialized.write(to: note.fileURL, atomically: true, encoding: .utf8)
            if let idx = notes.firstIndex(where: { $0.id == note.id }) {
                notes[idx] = note
            }
            logger.debug("Updated note: \(note.filename)")
        } catch {
            logger.error("Failed to save note \(note.filename): \(error)")
        }
    }

    // MARK: - Pin / Unpin

    func togglePin(_ note: NoteItem) {
        var updated = note
        updated.isPinned.toggle()
        updated.modifiedAt = Date()
        saveNote(updated)
    }

    // MARK: - Delete

    func deleteNote(_ note: NoteItem) {
        do {
            try fileManager.removeItem(at: note.fileURL)
            notes.removeAll { $0.id == note.id }
            logger.info("Deleted note: \(note.filename)")
        } catch {
            logger.error("Failed to delete note \(note.filename): \(error)")
        }
    }

    // MARK: - Actions

    func copyContent(_ note: NoteItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(note.content, forType: .string)
    }

    func openInDefaultEditor(_ note: NoteItem) {
        NSWorkspace.shared.open(note.fileURL)
    }

    func toggleTodo(note: NoteItem, lineIndex: Int) {
        let updated = note.togglingTodo(at: lineIndex)
        saveNote(updated)
    }

    // MARK: - Filtered Notes

    var filteredNotes: [NoteItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        let matching = notes.filter { note in
            let matchesSearch = query.isEmpty ||
                note.title.lowercased().contains(query) ||
                note.content.lowercased().contains(query)
            guard matchesSearch else { return false }

            switch filterCategory {
            case .all:
                return true
            case .notes:
                return !note.hasTodos
            case .todos:
                return note.hasTodos
            }
        }

        // Sort: pinned first, then newest createdAt
        return matching.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.createdAt > rhs.createdAt
        }
    }
}
