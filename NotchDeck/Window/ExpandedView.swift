// ExpandedView.swift
// Full dashboard shown in the expanded state.
// Uses a tab bar along the top to switch between widget panels.

import SwiftUI

struct ExpandedView: View {

    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var notesManager: NotesManager
    @ObservedObject var shelfManager: ShelfManager
    @ObservedObject var mediaManager: MediaManager
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var widgetRegistry: WidgetRegistry

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
            HomeDashboardView(
                configManager: configManager,
                mediaManager: mediaManager,
                calendarManager: calendarManager,
                widgetRegistry: widgetRegistry
            )
        case .notes:
            NotesView(notesManager: notesManager, viewModel: viewModel)
        case .shelf:
            ShelfView(shelfManager: shelfManager, copyOnDrop: configManager.config.general.copyOnDrop)
        case .terminal:
            TerminalPlaceholderView()
        case .vpn:
            if let widget = widgetRegistry.widget(id: "vpn-status") {
                widget.expandedView()
                    .padding(14)
            } else if let firstAction = widgetRegistry.widgets.first(where: { $0.id.contains("vpn") || $0.id.contains("status") }) {
                firstAction.expandedView()
                    .padding(14)
            } else {
                VPNPlaceholderView()
            }
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

// MARK: - Home Dashboard View

struct HomeDashboardView: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var mediaManager: MediaManager
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var widgetRegistry: WidgetRegistry

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(configManager.config.layout.home, id: \.self) { widgetId in
                    homeTile(for: widgetId)
                }
            }
            .padding(14)
        }
    }

    @ViewBuilder
    private func homeTile(for widgetId: String) -> some View {
        switch widgetId {
        case "media":
            MediaView(mediaManager: mediaManager)
        case "clock":
            ClockTile()
        case "calendar":
            CalendarWidgetTile(calendarManager: calendarManager)
        default:
            if let dynamicWidget = widgetRegistry.widget(id: widgetId) {
                dynamicWidget.expandedView()
            }
        }
    }
}

// MARK: - Clock Tile

struct ClockTile: View {
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date(), format: .dateTime.hour().minute().second())
                    .font(.system(size: 24, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide).year())
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Placeholder views

private struct TerminalPlaceholderView: View {
    var body: some View {
        placeholderLabel("Terminal — SwiftTerm integration (Phase 5)")
    }
}

private struct VPNPlaceholderView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.shield")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.3))
            Text("No VPN action widget defined in config.toml")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
            Text("Add an action widget with id = 'vpn-status' in config.toml")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private func placeholderLabel(_ text: String) -> some View {
    Text(text)
        .font(.caption)
        .opacity(0.4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
