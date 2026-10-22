// ShelfView.swift
// File and folder shelf dashboard view.
// Supports drag-in, drag-out, open, Finder reveal, path copy, and AirDrop.

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ShelfView: View {

    @ObservedObject var shelfManager: ShelfManager
    var copyOnDrop: Bool = false
    @Environment(\.deckTheme) private var theme: DeckTheme

    @State private var isTargetedForDrop: Bool = false
    @State private var hoveredItemId: UUID? = nil

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 8) {
            // Drop target header
            dropTargetHeader

            // Shelf items grid
            ScrollView {
                if shelfManager.items.isEmpty {
                    emptyShelfView
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(shelfManager.items) { item in
                            shelfItemCell(item)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargetedForDrop) { providers in
            handleDrop(providers: providers)
        }
    }

    // MARK: - Drop Header

    private var dropTargetHeader: some View {
        HStack {
            Image(systemName: "tray.and.arrow.down")
                .foregroundStyle(isTargetedForDrop ? theme.accent : theme.secondaryText)
            Text(isTargetedForDrop ? "Drop to pin to shelf" : "File Shelf")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isTargetedForDrop ? theme.accent : theme.primaryText)

            Spacer()

            Text("\(shelfManager.items.count) item\(shelfManager.items.count == 1 ? "" : "s")")
                .font(.system(size: 9))
                .foregroundStyle(theme.tertiaryText)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    // MARK: - Shelf Item Cell

    private func shelfItemCell(_ item: ShelfItem) -> some View {
        VStack(spacing: 6) {
            // File / Folder icon
            fileIcon(for: item)
                .frame(width: 44, height: 44)

            // Name
            Text(item.name)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.primaryText)

            // Kind indicator
            Text(item.isFolder ? "Folder" : (item.isCopied ? "Copied" : "Reference"))
                .font(.system(size: 8))
                .foregroundStyle(theme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(hoveredItemId == item.id ? theme.tabHover : theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(hoveredItemId == item.id ? theme.accent.opacity(0.6) : theme.cardBorder, lineWidth: 1)
        )
        .onHover { isHovered in
            hoveredItemId = isHovered ? item.id : nil
        }
        // Click to open
        .onTapGesture {
            shelfManager.openItem(item)
        }
        // Drag out to move into other apps
        .onDrag {
            NSItemProvider(contentsOf: item.url) ?? NSItemProvider(object: item.path as NSString)
        }
        // Right-click context menu
        .contextMenu {
            Button("Open") {
                shelfManager.openItem(item)
            }
            Button("Reveal in Finder") {
                shelfManager.revealInFinder(item)
            }
            Button("Copy Path") {
                shelfManager.copyPath(item)
            }
            Button("AirDrop…") {
                shelfManager.airDropItem(item)
            }
            Divider()
            Button("Remove from Shelf", role: .destructive) {
                shelfManager.removeItem(item)
            }
        }
    }

    private func fileIcon(for item: ShelfItem) -> some View {
        let nsImage = NSWorkspace.shared.icon(forFile: item.path)
        return Image(nsImage: nsImage)
            .resizable()
            .scaledToFit()
    }

    // MARK: - Empty State

    private var emptyShelfView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray.2")
                .font(.system(size: 32))
                .foregroundStyle(theme.tertiaryText)
                .padding(.top, 24)

            Text("Shelf is empty")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.secondaryText)

            Text("Drag and drop files or folders here\nor drop onto the notch directly")
                .font(.system(size: 10))
                .foregroundStyle(theme.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 24)
    }

    // MARK: - Drop Handling

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    shelfManager.addItem(from: url, copyOnDrop: copyOnDrop)
                }
            }
            handled = true
        }
        return handled
    }
}
