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

    private struct TabItemModel: Identifiable {
        let id: String
        let title: String
        let iconName: String
        let builtInTab: NotchTab?
    }

    private var customTabs: [AnyNotchWidget] {
        let configuredTabIds = configManager.config.layout.tabs
        return configuredTabIds.compactMap { tabId in
            if NotchTab(rawValue: tabId) == nil {
                return widgetRegistry.widget(id: tabId)
            }
            return nil
        }
    }

    private var allTabItems: [TabItemModel] {
        var items: [TabItemModel] = [
            TabItemModel(id: "home", title: "Home", iconName: "square.grid.2x2", builtInTab: .home),
            TabItemModel(id: "notes", title: "Notes", iconName: "note.text", builtInTab: .notes),
            TabItemModel(id: "shelf", title: "Shelf", iconName: "tray.2", builtInTab: .shelf),
            TabItemModel(id: "terminal", title: "Terminal", iconName: "terminal", builtInTab: .terminal),
            TabItemModel(id: "vpn", title: "VPN", iconName: "lock.shield", builtInTab: .vpn)
        ]

        for widget in customTabs {
            items.append(
                TabItemModel(
                    id: widget.id,
                    title: widget.title,
                    iconName: "square.dashed",
                    builtInTab: nil
                )
            )
        }
        return items
    }

    private var leftTabs: [TabItemModel] {
        Array(allTabItems.prefix(3))
    }

    private var rightTabs: [TabItemModel] {
        Array(allTabItems.dropFirst(3))
    }

    private var notchCenterCutout: some View {
        Button {
            viewModel.requestCollapse()
        } label: {
            ZStack {
                Rectangle()
                    .fill(Color.clear)

                VStack(spacing: 2) {
                    Image(systemName: "chevron.compact.up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                    Text("notch")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.2))
                }
            }
            .frame(width: max(viewModel.geometry.notchFrame.width + 16, 175), height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Click notch to close")
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            // Left tabs (3 tabs: Home, Notes, Shelf)
            HStack(spacing: 4) {
                ForEach(leftTabs) { item in
                    renderTabButton(item)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Center Notch cutout — matches hardware notch, clicking closes!
            notchCenterCutout

            // Right tabs (Terminal, VPN, etc.) + Close Button
            HStack(spacing: 4) {
                ForEach(rightTabs) { item in
                    renderTabButton(item)
                }

                // Close / collapse button
                Button {
                    viewModel.requestCollapse()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.medium)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .padding(.leading, 6)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
    }

    @ViewBuilder
    private func renderTabButton(_ item: TabItemModel) -> some View {
        if let tab = item.builtInTab {
            TabButton(
                tab: tab,
                isSelected: viewModel.activeCustomTabId == nil && viewModel.activeTab == tab
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.activeCustomTabId = nil
                    viewModel.activeTab = tab
                }
            }
        } else {
            CustomTabButton(
                id: item.id,
                title: item.title,
                isSelected: viewModel.activeCustomTabId == item.id
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.activeCustomTabId = item.id
                }
            }
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        if let customId = viewModel.activeCustomTabId, let widget = widgetRegistry.widget(id: customId) {
            widget.expandedView()
                .padding(10)
        } else {
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
                TerminalView()
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

private struct CustomTabButton: View {
    let id: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: "square.dashed")
                    .imageScale(.small)
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
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
