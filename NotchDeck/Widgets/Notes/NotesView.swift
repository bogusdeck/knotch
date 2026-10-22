// NotesView.swift
// Full notes dashboard inside the expanded notch.
// Supports quick note capture, search, pin, copy, delete, and editor launch.

import SwiftUI

struct NotesView: View {

    @ObservedObject var notesManager: NotesManager
    @ObservedObject var viewModel: NotchViewModel
    @Environment(\.deckTheme) private var theme: DeckTheme

    @State private var quickText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var hoveredNoteId: String? = nil
    @State private var copiedNoteId: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            // Quick note entry bar
            quickInputSection

            // Search bar
            searchSection

            // Notes list
            notesListSection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            notesManager.loadNotes()
            if viewModel.requestFocusOnNoteInput {
                isInputFocused = true
                viewModel.requestFocusOnNoteInput = false
            }
        }
        .onChange(of: viewModel.requestFocusOnNoteInput) { _, newValue in
            if newValue {
                isInputFocused = true
                viewModel.requestFocusOnNoteInput = false
            }
        }
    }

    // MARK: - Quick Input Section

    private var quickInputSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(theme.accent)
                    .imageScale(.medium)

                TextField("Take a quick note...", text: $quickText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .lineLimit(1...4)
                    .onKeyPress(.return, phases: .down) { press in
                        if press.modifiers.contains(.shift) {
                            quickText.append("\n")
                            return .handled
                        } else {
                            saveQuickNote()
                            return .handled
                        }
                    }
                    .onKeyPress(.escape) {
                        viewModel.state = .collapsed
                        return .handled
                    }

                if !quickText.isEmpty {
                    Button(action: saveQuickNote) {
                        Text("Save")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(theme.accent)
                            .foregroundStyle(.white)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
            }
            .padding(10)
            .background(theme.cardBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isInputFocused ? theme.accent.opacity(0.6) : theme.cardBorder, lineWidth: 1)
            )

            HStack {
                Text("⏎ to save • ⇧⏎ for newline • Esc to close")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.tertiaryText)
                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }

    private func saveQuickNote() {
        let trimmed = quickText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        notesManager.createNote(content: trimmed)
        quickText = ""
    }

    // MARK: - Search Section

    private var searchSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .imageScale(.small)
                .foregroundStyle(theme.tertiaryText)

            TextField("Search notes...", text: $notesManager.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 11))

            if !notesManager.searchQuery.isEmpty {
                Button {
                    notesManager.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.small)
                        .foregroundStyle(theme.tertiaryText)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(theme.inputBackground)
        .cornerRadius(6)
    }

    // MARK: - Notes List Section

    private var notesListSection: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                let items = notesManager.filteredNotes
                if items.isEmpty {
                    emptyStateView
                } else {
                    ForEach(items) { note in
                        noteRow(note)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func noteRow(_ note: NoteItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Pin status / button
            Button {
                notesManager.togglePin(note)
            } label: {
                Image(systemName: note.isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(note.isPinned ? .yellow : .white.opacity(0.3))
                    .imageScale(.small)
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .padding(.top, 2)

            // Content snippet
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(note.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)

                    Spacer()

                    Text(note.createdAt, style: .date)
                        .font(.system(size: 9))
                        .foregroundStyle(theme.tertiaryText)
                }

                if !note.preview.isEmpty {
                    Text(note.preview)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Action buttons on hover
            if hoveredNoteId == note.id {
                HStack(spacing: 6) {
                    // Copy
                    Button {
                        notesManager.copyContent(note)
                        copiedNoteId = note.id
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            if copiedNoteId == note.id { copiedNoteId = nil }
                        }
                    } label: {
                        Image(systemName: copiedNoteId == note.id ? "checkmark" : "doc.on.doc")
                            .imageScale(.small)
                            .foregroundStyle(copiedNoteId == note.id ? .green : theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    .help("Copy content")

                    // Open in default editor
                    Button {
                        notesManager.openInDefaultEditor(note)
                    } label: {
                        Image(systemName: "arrow.up.forward.square")
                            .imageScale(.small)
                            .foregroundStyle(theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    .help("Open in default editor")

                    // Delete
                    Button {
                        notesManager.deleteNote(note)
                    } label: {
                        Image(systemName: "trash")
                            .imageScale(.small)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    .help("Delete note")
                }
                .transition(.opacity)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(note.isPinned ? Color.yellow.opacity(0.12) : theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(note.isPinned ? Color.yellow.opacity(0.3) : theme.cardBorder, lineWidth: 1)
        )
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredNoteId = isHovered ? note.id : nil
            }
        }
        .contextMenu {
            Button(note.isPinned ? "Unpin Note" : "Pin Note") {
                notesManager.togglePin(note)
            }
            Button("Copy Content") {
                notesManager.copyContent(note)
            }
            Button("Open in Default Editor") {
                notesManager.openInDefaultEditor(note)
            }
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([note.fileURL])
            }
            Divider()
            Button("Delete Note", role: .destructive) {
                notesManager.deleteNote(note)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 6) {
            Image(systemName: "note.text")
                .imageScale(.large)
                .foregroundStyle(theme.tertiaryText)
                .padding(.top, 16)
            Text(notesManager.searchQuery.isEmpty ? "No notes yet" : "No matching notes")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.secondaryText)
            Text("Notes are saved to ~/.config/notchdeck/notes/")
                .font(.system(size: 9))
                .foregroundStyle(theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 16)
    }
}
