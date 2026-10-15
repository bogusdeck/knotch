// TerminalWidget.swift
// Conforms embedded terminal to the NotchWidget protocol.

import SwiftUI

struct TerminalWidget: NotchWidget {
    let id: String
    let title: String
    let iconName: String?

    init(id: String = "terminal", title: String = "Terminal", iconName: String? = "terminal") {
        self.id = id
        self.title = title
        self.iconName = iconName
    }

    func compactView() -> AnyView {
        AnyView(
            TerminalCompactView()
        )
    }

    func expandedView() -> AnyView {
        AnyView(
            TerminalView()
        )
    }
}

private struct TerminalCompactView: View {
    @ObservedObject var manager = TerminalManager.shared

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "terminal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.accentColor)

            if let active = manager.activeSession {
                Circle()
                    .fill(active.isRunning ? Color.green : Color.secondary)
                    .frame(width: 5, height: 5)
                Text(active.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            } else {
                Text("Idle")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}
