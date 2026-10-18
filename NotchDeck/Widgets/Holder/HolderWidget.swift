// HolderWidget.swift
// NotchWidget conforming wrapper for the Application & Document Holder.

import SwiftUI

@MainActor
final class HolderWidget: NotchWidget {

    let id: String = "holder"
    let title: String = "Holder"

    let holderManager: HolderManager

    init(holderManager: HolderManager) {
        self.holderManager = holderManager
    }

    func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 6) {
                Image(systemName: "macwindow.on.rectangle")
                    .imageScale(.small)
                    .foregroundStyle(.purple)

                Text("\(holderManager.items.count) item\(holderManager.items.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .opacity(0.7)
            }
        )
    }

    func expandedView() -> AnyView {
        AnyView(
            HolderView(holderManager: holderManager)
        )
    }
}
