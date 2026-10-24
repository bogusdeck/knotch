// NotesView.swift
// Full notes dashboard inside the expanded notch.
// Supports quick note capture, search, pin, copy, delete, and editor launch.

import SwiftUI

struct NotesView: View {

    @ObservedObject var notesManager: NotesManager
    @ObservedObject var viewModel: NotchViewModel
    @Environment(\.deckTheme) private var theme: DeckTheme

    @State private var quickText: String = ""
    @State private var isTodoMode: Bool = false
    @FocusState private var isInputFocused: Bool
    @State private var hoveredNoteId: String? = nil
    @State private var copiedNoteId: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            // Quick note / todo entry bar
            quickInputSection

            // Search bar & Category filters
            filterAndSearchSection

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
                // Mode Toggle Button (Note vs Todo)
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                        isTodoMode.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isTodoMode ? "checkmark.square.fill" : "square.and.pencil")
                            .foregroundStyle(isTodoMode ? theme.accent : theme.secondaryText)
                            .imageScale(.medium)

                        Text(isTodoMode ? "Todo" : "Note")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isTodoMode ? theme.accent : theme.secondaryText)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isTodoMode ? theme.accent.opacity(0.18) : theme.inputBackground.opacity(0.5))
                    )
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .help(isTodoMode ? "Switch to Normal Note" : "Switch to Todo Checklist (or type [])")

                TextField(isTodoMode ? "Add a todo item (or type [])..." : "Take a quick note (or type [] for todos)...", text: $quickText, axis: .vertical)
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

                // Quick [] Insert Button
                if !isTodoMode && !quickText.hasPrefix("[]") && !quickText.hasPrefix("- [ ]") {
                    Button {
                        quickText = "- [ ] " + quickText
                        isTodoMode = true
                    } label: {
                        Text("[]")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(theme.secondaryText)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(theme.inputBackground))
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    .help("Insert Todo Checkbox")
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
            .padding(9)
            .background(theme.cardBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isInputFocused ? theme.accent.opacity(0.6) : theme.cardBorder, lineWidth: 1)
            )

            HStack {
                Text("⏎ save • ⇧⏎ newline • type [] for todos • Esc close")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.tertiaryText)
                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }

    private func saveQuickNote() {
        var trimmed = quickText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if isTodoMode {
            if !trimmed.contains("[ ]") && !trimmed.contains("[]") && !trimmed.contains("[x]") && !trimmed.contains("[X]") {
                trimmed = "- [ ] " + trimmed
            } else if trimmed.hasPrefix("[] ") {
                trimmed = "- [ ] " + String(trimmed.dropFirst(3))
            }
        } else {
            if trimmed.hasPrefix("[] ") {
                trimmed = "- [ ] " + String(trimmed.dropFirst(3))
            }
        }

        notesManager.createNote(content: trimmed)
        quickText = ""
    }

    // MARK: - Search & Filter Section

    private var filterAndSearchSection: some View {
        HStack(spacing: 8) {
            // Category Filter Pills
            HStack(spacing: 4) {
                ForEach(NoteFilterCategory.allCases) { cat in
                    let count: Int = {
                        switch cat {
                        case .all: return notesManager.notes.count
                        case .notes: return notesManager.notes.filter { !$0.hasTodos }.count
                        case .todos: return notesManager.notes.filter { $0.hasTodos }.count
                        }
                    }()
                    let isSelected = notesManager.filterCategory == cat

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            notesManager.filterCategory = cat
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 9))
                            Text("\(cat.rawValue) (\(count))")
                                .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                        }
                        .foregroundStyle(isSelected ? Color.white : theme.secondaryText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(
                            Capsule()
                                .fill(isSelected ? theme.accent.opacity(0.85) : theme.inputBackground.opacity(0.6))
                        )
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
            }

            Spacer()

            // Search Bar
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .imageScale(.small)
                    .foregroundStyle(theme.tertiaryText)

                TextField("Search...", text: $notesManager.searchQuery)
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
            .frame(maxWidth: 160)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(theme.inputBackground)
            .cornerRadius(6)
        }
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

            // Content snippet & interactive checklist
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center, spacing: 6) {
                    if note.hasTodos {
                        Image(systemName: "checklist")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(theme.accent)
                    }

                    Text(note.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)

                    if note.hasTodos {
                        let (done, total) = note.todoStats
                        Text("\(done)/\(total)")
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundStyle(done == total && total > 0 ? Color.green : theme.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(
                                Capsule()
                                    .fill(done == total && total > 0 ? Color.green.opacity(0.15) : theme.accent.opacity(0.15))
                            )
                    }

                    Spacer()

                    Text(note.createdAt, style: .date)
                        .font(.system(size: 9))
                        .foregroundStyle(theme.tertiaryText)
                }

                if note.hasTodos {
                    // Render interactive checklist lines
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(note.parsedLines) { lineItem in
                            if lineItem.isTodo {
                                Button {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                        notesManager.toggleTodo(note: note, lineIndex: lineItem.id)
                                    }
                                } label: {
                                    HStack(alignment: .center, spacing: 6) {
                                        Image(systemName: lineItem.isCompleted ? "checkmark.square.fill" : "square")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(lineItem.isCompleted ? theme.accent : theme.secondaryText)

                                        Text(lineItem.text)
                                            .font(.system(size: 11))
                                            .strikethrough(lineItem.isCompleted, color: theme.tertiaryText)
                                            .foregroundStyle(lineItem.isCompleted ? theme.tertiaryText : theme.primaryText)
                                            .lineLimit(2)
                                    }
                                }
                                .buttonStyle(.plain)
                                .pointingHandCursor()
                            } else if !lineItem.text.isEmpty && lineItem.text != note.title {
                                Text(lineItem.text)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(theme.secondaryText)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.top, 2)
                } else if !note.preview.isEmpty {
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
