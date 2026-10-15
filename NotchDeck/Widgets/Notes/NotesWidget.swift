// NotesWidget.swift
// NotchWidget conforming wrapper for the Quick Notes feature.

import SwiftUI

@MainActor
final class NotesWidget: NotchWidget {

    let id: String = "notes"
    let title: String = "Notes"

    let notesManager: NotesManager
    private weak var viewModel: NotchViewModel?

    init(notesManager: NotesManager, viewModel: NotchViewModel? = nil) {
        self.notesManager = notesManager
        self.viewModel = viewModel
    }

    func setViewModel(_ viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }

    func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .imageScale(.small)
                    .foregroundStyle(.purple)

                if let latest = notesManager.filteredNotes.first {
                    Text(latest.title)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                } else {
                    Text("No notes")
                        .font(.system(size: 11))
                        .opacity(0.6)
                }
            }
        )
    }

    func expandedView() -> AnyView {
        guard let viewModel else {
            return AnyView(Text("Notes View Unavailable").font(.caption))
        }
        return AnyView(
            NotesView(notesManager: notesManager, viewModel: viewModel)
        )
    }
}
