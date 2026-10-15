// ShelfWidget.swift
// NotchWidget conforming wrapper for the File & Folder Shelf.

import SwiftUI

@MainActor
final class ShelfWidget: NotchWidget {

    let id: String = "shelf"
    let title: String = "Shelf"

    let shelfManager: ShelfManager
    var copyOnDrop: Bool = false

    init(shelfManager: ShelfManager, copyOnDrop: Bool = false) {
        self.shelfManager = shelfManager
        self.copyOnDrop = copyOnDrop
    }

    func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 6) {
                Image(systemName: "tray.2")
                    .imageScale(.small)
                    .foregroundStyle(.cyan)

                Text("\(shelfManager.items.count) item\(shelfManager.items.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .opacity(0.7)
            }
        )
    }

    func expandedView() -> AnyView {
        AnyView(
            ShelfView(shelfManager: shelfManager, copyOnDrop: copyOnDrop)
        )
    }
}
