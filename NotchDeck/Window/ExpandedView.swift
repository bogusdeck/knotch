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

    @State private var isNotchHovered: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar matching notch height
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
                RoundedRectangle(cornerRadius: 6)
                    .fill(isNotchHovered ? Color.white.opacity(0.06) : Color.clear)

                HStack(spacing: 4) {
                    Image(systemName: "chevron.compact.up")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isNotchHovered ? .white.opacity(0.7) : .white.opacity(0.35))
                    Text("notch")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(isNotchHovered ? .white.opacity(0.5) : .white.opacity(0.2))
                }
            }
            .frame(width: max(viewModel.geometry.notchFrame.width + 16, 175))
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            isNotchHovered = hovering
        }
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
                TabCloseButton {
                    viewModel.requestCollapse()
                }
                .padding(.leading, 3)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .frame(height: max(viewModel.geometry.notchFrame.height, 30))
    }

    @ViewBuilder
    private func renderTabButton(_ item: TabItemModel) -> some View {
        if let tab = item.builtInTab {
            if tab == .vpn, let vpnWidget = widgetRegistry.actionWidget(id: "vpn-status") ?? widgetRegistry.allActionWidgets.first(where: { $0.id.contains("vpn") }) {
                VPNTopBarToggle(widget: vpnWidget, isSelected: false) {
                    // Single click = instant direct toggle without opening any card!
                    if let toggleBtn = vpnWidget.config.buttons.first(where: { $0.label.lowercased().contains("toggle") }) {
                        Task { await vpnWidget.executeButton(toggleBtn) }
                    } else if let firstBtn = vpnWidget.config.buttons.first {
                        Task { await vpnWidget.executeButton(firstBtn) }
                    }
                } onOpenTab: {
                    // User does not want to open card; keep on current tab
                }
            } else {
                TabButton(
                    tab: tab,
                    isSelected: viewModel.activeCustomTabId == nil && viewModel.activeTab == tab
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.activeCustomTabId = nil
                        viewModel.activeTab = tab
                    }
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
                if let actionWidget = widgetRegistry.actionWidget(id: "vpn-status") ?? widgetRegistry.allActionWidgets.first(where: { $0.id.contains("vpn") }) {
                    VPNView(widget: actionWidget)
                } else if let widget = widgetRegistry.widget(id: "vpn-status") {
                    widget.expandedView()
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

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                Text(tab.displayName)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : (isHovered ? .white.opacity(0.9) : .white.opacity(0.5)))
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected
                            ? Color.white.opacity(0.14)
                            : (isHovered ? Color.white.opacity(0.07) : Color.clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct CustomTabButton: View {
    let id: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "square.dashed")
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : (isHovered ? .white.opacity(0.9) : .white.opacity(0.5)))
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected
                            ? Color.white.opacity(0.14)
                            : (isHovered ? Color.white.opacity(0.07) : Color.clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct VPNTopBarToggle: View {
    @ObservedObject var widget: ActionWidget
    let isSelected: Bool
    let onToggle: () -> Void
    let onOpenTab: () -> Void

    @State private var isHovered: Bool = false

    private var isConnected: Bool {
        widget.status == .active
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 5) {
                if widget.isExecuting {
                    ProgressView()
                        .scaleEffect(0.55)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: isConnected ? "lock.shield.fill" : "lock.shield")
                        .font(.system(size: 11, weight: isConnected ? .semibold : .regular))
                        .foregroundStyle(isConnected ? Color.green : (isHovered ? .white : .white.opacity(0.5)))
                }

                Text(isConnected ? "VPN On" : "VPN")
                    .font(.system(size: 10, weight: isConnected ? .semibold : .medium))
                    .foregroundStyle(isConnected ? Color.green : (isHovered ? .white.opacity(0.9) : .white.opacity(0.5)))
                    .lineLimit(1)
            }
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isConnected
                            ? Color.green.opacity(0.18)
                            : (isHovered ? Color.white.opacity(0.08) : Color.clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Toggle VPN") {
                onToggle()
            }
            Button("Open VPN Details") {
                onOpenTab()
            }
        }
        .help(isConnected ? "VPN Connected (Click to disconnect)" : "VPN Disconnected (Click to connect)")
    }
}

private struct TabCloseButton: View {
    let action: () -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(isHovered ? .white.opacity(0.9) : .white.opacity(0.45))
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(isHovered ? Color.white.opacity(0.1) : Color.clear)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .onHover { hovering in
            isHovered = hovering
        }
        .help("Close notch")
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

// MARK: - Dedicated VPN View

struct VPNView: View {
    @ObservedObject var widget: ActionWidget

    var isConnected: Bool {
        widget.status == .active
    }

    var body: some View {
        HStack(spacing: 24) {
            // Left: Status Shield
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isConnected ? Color.green.opacity(0.15) : Color.white.opacity(0.06))
                        .frame(width: 64, height: 64)

                    Image(systemName: isConnected ? "lock.shield.fill" : "lock.shield")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(isConnected ? Color.green : Color.white.opacity(0.5))
                }

                Text(widget.status.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isConnected ? Color.green : Color.white.opacity(0.6))
            }
            .frame(width: 110)

            Divider()
                .overlay(Color.white.opacity(0.1))
                .frame(height: 100)

            // Right: Info & Controls
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(widget.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    // Refresh
                    Button {
                        Task { await widget.pollStatus() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Refresh VPN status")
                }

                if !widget.lastOutput.isEmpty {
                    Text(widget.lastOutput)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(4)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(6)
                }

                // Action buttons
                if !widget.config.buttons.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(widget.config.buttons, id: \.label) { button in
                            Button {
                                Task { await widget.executeButton(button) }
                            } label: {
                                HStack(spacing: 5) {
                                    if button.label.lowercased().contains("toggle") {
                                        Image(systemName: "power")
                                    } else if button.label.lowercased().contains("connect") && !button.label.lowercased().contains("dis") {
                                        Image(systemName: "bolt.fill")
                                    } else if button.label.lowercased().contains("disconnect") {
                                        Image(systemName: "stop.fill")
                                    }
                                    Text(button.label)
                                        .fontWeight(.medium)
                                }
                                .font(.system(size: 11))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(buttonColor(for: button.label))
                                .foregroundStyle(.white)
                                .cornerRadius(7)
                            }
                            .buttonStyle(.plain)
                            .disabled(widget.isExecuting)
                        }

                        if widget.isExecuting {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func buttonColor(for label: String) -> Color {
        let lower = label.lowercased()
        if lower.contains("toggle") {
            return isConnected ? Color.red.opacity(0.8) : Color.green.opacity(0.8)
        } else if lower.contains("connect") && !lower.contains("dis") {
            return Color.green.opacity(0.7)
        } else if lower.contains("disconnect") {
            return Color.red.opacity(0.7)
        }
        return Color.white.opacity(0.15)
    }
}
