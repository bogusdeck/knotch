// NotesManagerTests.swift
// Unit tests for NotesManager and NoteItem markdown parsing/serialization.

import XCTest
@testable import NotchDeck

@MainActor
final class NotesManagerTests: XCTestCase {

    var tempDir: URL!
    var notesManager: NotesManager!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotchDeckNotesTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        notesManager = NotesManager(notesDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testCreateNote() {
        let note = notesManager.createNote(content: "# Meeting Notes\nDiscuss project roadmap")
        XCTAssertNotNil(note)
        XCTAssertEqual(note?.title, "Meeting Notes")
        XCTAssertTrue(note?.preview.contains("Discuss project roadmap") ?? false)
        XCTAssertEqual(notesManager.notes.count, 1)

        // File should exist on disk
        if let fileURL = note?.fileURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    func testCreateEmptyNoteReturnsNil() {
        let note = notesManager.createNote(content: "   \n\n  ")
        XCTAssertNil(note)
        XCTAssertEqual(notesManager.notes.count, 0)
    }

    func testFrontmatterSerializationAndParsing() {
        let note = notesManager.createNote(content: "Test note body", isPinned: true)
        XCTAssertNotNil(note)
        guard let note else { return }

        XCTAssertTrue(note.isPinned)

        // Re-read raw content from disk
        let rawContent = try? String(contentsOf: note.fileURL, encoding: .utf8)
        XCTAssertNotNil(rawContent)
        XCTAssertTrue(rawContent?.contains("pinned: true") ?? false)

        // Parse back
        let parsed = NoteItem.parse(
            from: note.fileURL,
            rawText: rawContent!,
            fileDates: (note.createdAt, note.modifiedAt)
        )
        XCTAssertEqual(parsed.id, note.id)
        XCTAssertEqual(parsed.content, "Test note body")
        XCTAssertTrue(parsed.isPinned)
    }

    func testTogglePin() {
        guard let note = notesManager.createNote(content: "Pin test") else {
            XCTFail("Failed to create note")
            return
        }

        XCTAssertFalse(note.isPinned)
        notesManager.togglePin(note)

        let updated = notesManager.notes.first { $0.id == note.id }
        XCTAssertTrue(updated?.isPinned ?? false)

        notesManager.togglePin(updated!)
        let unpinned = notesManager.notes.first { $0.id == note.id }
        XCTAssertFalse(unpinned?.isPinned ?? true)
    }

    func testSearchFiltering() {
        notesManager.createNote(content: "# Alpha Note\nFirst note content")
        notesManager.createNote(content: "# Beta Note\nSecond note content")
        notesManager.createNote(content: "# Gamma Note\nThird note content")

        notesManager.searchQuery = "beta"
        let filtered = notesManager.filteredNotes
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.title, "Beta Note")

        notesManager.searchQuery = "content"
        XCTAssertEqual(notesManager.filteredNotes.count, 3)

        notesManager.searchQuery = "nonexistent"
        XCTAssertEqual(notesManager.filteredNotes.count, 0)
    }

    func testDeleteNote() {
        guard let note = notesManager.createNote(content: "Delete me") else {
            XCTFail("Failed to create note")
            return
        }

        XCTAssertEqual(notesManager.notes.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: note.fileURL.path))

        notesManager.deleteNote(note)
        XCTAssertEqual(notesManager.notes.count, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: note.fileURL.path))
    }

    func testTodoParsingAndToggling() {
        guard let note = notesManager.createNote(content: "# My List\n- [ ] Buy groceries\n- [x] Read book\n[] Walk dog") else {
            XCTFail("Failed to create todo note")
            return
        }

        XCTAssertTrue(note.hasTodos)
        let stats = note.todoStats
        XCTAssertEqual(stats.total, 3)
        XCTAssertEqual(stats.completed, 1)

        // Toggle line 1 (- [ ] Buy groceries -> - [x] Buy groceries)
        notesManager.toggleTodo(note: note, lineIndex: 1)
        let updated = notesManager.notes.first { $0.id == note.id }!
        XCTAssertEqual(updated.todoStats.completed, 2)
        XCTAssertTrue(updated.content.contains("- [x] Buy groceries"))

        // Toggle line 2 (- [x] Read book -> - [ ] Read book)
        notesManager.toggleTodo(note: updated, lineIndex: 2)
        let updated2 = notesManager.notes.first { $0.id == note.id }!
        XCTAssertEqual(updated2.todoStats.completed, 1)
        XCTAssertTrue(updated2.content.contains("- [ ] Read book"))
    }

    func testCategoryFilteringNotesAndTodos() {
        notesManager.createNote(content: "Pure plain note with text")
        notesManager.createNote(content: "- [ ] A task to do")

        // All category
        notesManager.filterCategory = .all
        XCTAssertEqual(notesManager.filteredNotes.count, 2)

        // Notes only category
        notesManager.filterCategory = .notes
        XCTAssertEqual(notesManager.filteredNotes.count, 1)
        XCTAssertFalse(notesManager.filteredNotes.first!.hasTodos)

        // Todos only category
        notesManager.filterCategory = .todos
        XCTAssertEqual(notesManager.filteredNotes.count, 1)
        XCTAssertTrue(notesManager.filteredNotes.first!.hasTodos)
    }
}
