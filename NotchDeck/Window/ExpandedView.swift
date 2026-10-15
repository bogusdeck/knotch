// ExpandedView.swift
// Full dashboard shown in the expanded state.
// Uses a tab bar along the top to switch between widget panels.

import SwiftUI

struct ExpandedView: View {

    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var notesManager: NotesManager
    @ObservedObject var shelfManager: ShelfManager

    var body: some View {
        VStack(spacing: 0) {
            // Narrow gap from the top of the panel (where the notch merges)
            Spacer().frame(height: 8)

            // Tab bar
            tabBar

            Divider().overlay(.white.opacity(0.1))

            // Tab content
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(NotchTab.allCases, id: \.self) { tab in
                TabButton(tab: tab, isSelected: viewModel.activeTab == tab) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.activeTab = tab
                    }
                }
            }
            Spacer()
            // Close / collapse button
            Button {
                viewModel.requestCollapse()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .imageScale(.medium)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
        }
        .padding(.horizontal, 8)
        .frame(height: 36)
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.activeTab {
        case .home:
            HomeView()
        case .notes:
            NotesView(notesManager: notesManager, viewModel: viewModel)
        case .shelf:
            ShelfView(shelfManager: shelfManager, copyOnDrop: configManager.config.general.copyOnDrop)
        case .terminal:
            TerminalPlaceholderView()
        case .vpn:
            VPNPlaceholderView()
        }
    }
}

// MARK: - Tab button

private struct TabButton: View {
    let tab: NotchTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: tab.iconName)
                    .imageScale(.small)
                Text(tab.displayName)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.45))
            .frame(width: 52, height: 36)
            .background(
                isSelected
                    ? RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08))
                    : nil
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tab metadata

extension NotchTab {
    var displayName: String {
        switch self {
        case .home:     "Home"
        case .notes:    "Notes"
        case .shelf:    "Shelf"
        case .terminal: "Terminal"
        case .vpn:      "VPN"
        }
    }

    var iconName: String {
        switch self {
        case .home:     "square.grid.2x2"
        case .notes:    "note.text"
        case .shelf:    "tray.2"
        case .terminal: "terminal"
        case .vpn:      "lock.shield"
        }
    }
}

// MARK: - Home view

private struct HomeView: View {
    var body: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to NotchDeck")
                    .font(.headline)
                Text("Phase 3 — Quick notes & file shelf ready.")
                    .font(.caption)
                    .opacity(0.6)
            }
            Spacer()
            // Live clock tile
            VStack(spacing: 2) {
                Text(Date(), format: .dateTime.hour().minute().second())
                    .font(.system(size: 28, weight: .thin, design: .rounded))
                    .monospacedDigit()
                Text(Date(), format: .dateTime.day().month(.wide).year())
                    .font(.caption2)
                    .opacity(0.6)
            }
        }
        .padding(16)
    }
}

// MARK: - Placeholder views (replaced in subsequent phases)

private struct TerminalPlaceholderView: View {
    var body: some View {
        placeholderLabel("Terminal — SwiftTerm integration (Phase 5)")
    }
}

private struct VPNPlaceholderView: View {
    var body: some View {
        placeholderLabel("VPN widget — action widget (Phase 4)")
    }
}

private func placeholderLabel(_ text: String) -> some View {
    Text(text)
        .font(.caption)
        .opacity(0.4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
