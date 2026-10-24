// ExpandedView.swift
// Full dashboard shown in the expanded state.
// Uses a tab bar along the top to switch between widget panels.

import Darwin
import IOKit.ps
import SwiftUI

struct ExpandedView: View {

    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var notesManager: NotesManager
    @ObservedObject var shelfManager: ShelfManager
    @ObservedObject var holderManager: HolderManager
    @ObservedObject var mediaManager: MediaManager
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var widgetRegistry: WidgetRegistry

    @State private var isNotchHovered: Bool = false
    @State private var isQuitHovered: Bool = false
    @State private var isExpandedDropTargeted: Bool = false

    private var currentTheme: DeckTheme {
        DeckTheme.current(
            theme: configManager.config.appearance.theme,
            accentHex: configManager.config.appearance.accent
        )
    }

    var body: some View {
        let theme = currentTheme
        VStack(spacing: 0) {
            // Tab bar matching notch height
            tabBar

            Divider().overlay(theme.divider)

            // Tab content
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(theme.primaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: DropURLHelper.supportedDropTypes, isTargeted: $isExpandedDropTargeted) { providers in
            DropURLHelper.extractURLs(from: providers) { urls in
                for url in urls {
                    holderManager.addItem(from: url)
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.activeTab = .holder
                }
            }
            return true
        }
        .onExitCommand {
            if viewModel.isSettingsActive {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.isSettingsActive = false
                }
            } else {
                viewModel.requestCollapse()
            }
        }
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
        let layout = configManager.config.layout
        let configured: [String]

        if viewModel.isWorkMode {
            if let customWork = layout.workTabs, !customWork.isEmpty {
                configured = customWork
            } else {
                // In Work mode: Google Chat and other work tools are visible; personal messaging (WhatsApp) is hidden
                configured = layout.tabs.filter { id in
                    let lower = id.lowercased()
                    return lower != "whatsapp"
                }
            }
        } else {
            if let customPersonal = layout.personalTabs, !customPersonal.isEmpty {
                configured = customPersonal
            } else {
                // In Personal mode: WhatsApp is visible; work-specific chat (Google Chat) is hidden
                configured = layout.tabs.filter { id in
                    let lower = id.lowercased()
                    return lower != "googlechat" && lower != "gchat" && lower != "chat"
                }
            }
        }

        var items: [TabItemModel] = []
        for tabId in configured {
            switch tabId {
            case "home":
                items.append(TabItemModel(id: "home", title: "Home", iconName: "square.grid.2x2", builtInTab: .home))
            case "notes":
                items.append(TabItemModel(id: "notes", title: "Notes", iconName: "note.text", builtInTab: .notes))
            case "googlechat", "gchat", "chat":
                items.append(TabItemModel(id: "googlechat", title: "Chat", iconName: "bubble.left.and.bubble.right.fill", builtInTab: .googlechat))
            case "whatsapp":
                items.append(TabItemModel(id: "whatsapp", title: "WhatsApp", iconName: "message.fill", builtInTab: .whatsapp))
            case "gpt", "chatgpt", "openai":
                items.append(TabItemModel(id: "gpt", title: "ChatGPT", iconName: "sparkles", builtInTab: .gpt))
            case "claude", "anthropic":
                items.append(TabItemModel(id: "claude", title: "Claude", iconName: "brain.head.profile", builtInTab: .claude))
            case "slack", "slackterm", "slack-term":
                items.append(TabItemModel(id: "slack", title: "Slack", iconName: "number", builtInTab: .slack))
            case "holder":
                items.append(TabItemModel(id: "holder", title: "Holder", iconName: "macwindow.on.rectangle", builtInTab: .holder))
            case "web", "browser":
                items.append(TabItemModel(id: "web", title: "Web", iconName: "globe", builtInTab: .web))
            case "shelf":
                items.append(TabItemModel(id: "shelf", title: "Shelf", iconName: "tray.2", builtInTab: .shelf))
            case "terminal":
                items.append(TabItemModel(id: "terminal", title: "Terminal", iconName: "terminal", builtInTab: .terminal))
            case "vpn":
                items.append(TabItemModel(id: "vpn", title: "VPN", iconName: "lock.shield", builtInTab: .vpn))
            default:
                if let widget = widgetRegistry.widget(id: tabId) {
                    let customIcon = configManager.config.widgets.first(where: { $0.id == tabId })?.icon ?? "square.dashed"
                    items.append(TabItemModel(id: widget.id, title: widget.title, iconName: customIcon, builtInTab: nil))
                } else if let widgetCfg = configManager.config.widgets.first(where: { $0.id == tabId }) {
                    items.append(TabItemModel(
                        id: widgetCfg.id,
                        title: widgetCfg.title.isEmpty ? widgetCfg.id.capitalized : widgetCfg.title,
                        iconName: widgetCfg.icon ?? "globe",
                        builtInTab: nil
                    ))
                }
            }
        }
        return items
    }

    private var notchCutoutWidth: CGFloat {
        max(viewModel.geometry.notchFrame.width + 16, 175)
    }

    private var leftTabs: [TabItemModel] {
        // Balance left vs right accounting for the Settings button on the left
        let split = allTabItems.count / 2
        return Array(allTabItems.prefix(split))
    }

    private var rightTabs: [TabItemModel] {
        let split = allTabItems.count / 2
        return Array(allTabItems.dropFirst(split))
    }

    private var notchCenterCutout: some View {
        ZStack {
            // Main notch area: click to collapse drawer
            Button {
                viewModel.requestCollapse()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isNotchHovered ? currentTheme.tabHover : Color.clear)

                    HStack(spacing: 4) {
                        Image(systemName: "chevron.compact.up")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isNotchHovered ? currentTheme.primaryText.opacity(0.8) : currentTheme.secondaryText)
                        Text("notch")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(isNotchHovered ? currentTheme.secondaryText : currentTheme.tertiaryText)
                    }
                }
                .frame(width: notchCutoutWidth)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .onHover { hovering in
                isNotchHovered = hovering
            }
            .help("Click notch to close (ESC)")

            // Cross button: Stop/quit the whole application
            HStack {
                Spacer()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    ZStack {
                        Circle()
                            .fill(isQuitHovered ? Color.red.opacity(0.2) : Color.white.opacity(0.08))
                            .frame(width: 17, height: 17)

                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(isQuitHovered ? Color(red: 1.0, green: 0.35, blue: 0.35) : currentTheme.secondaryText)
                    }
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .onHover { hovering in
                    isQuitHovered = hovering
                }
                .help("Stop / Quit NotchDeck Application")
                .padding(.trailing, 4)
            }
            .frame(width: notchCutoutWidth)
        }
        .frame(width: notchCutoutWidth)
    }

    @ViewBuilder
    private var tabBar: some View {
        if viewModel.isSettingsActive {
            settingsTabBar
        } else {
            normalTabBar
        }
    }

    private var normalTabBar: some View {
        ZStack(alignment: .center) {
            // Left & Right tab bars with center spacer
            HStack(spacing: 0) {
                // Left top corner: Settings button on the leftmost side + Left tabs (Home, Notes, Shelf)
                HStack(spacing: 5) {
                    SettingsButton(isLight: currentTheme.isLight) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.isSettingsActive = true
                        }
                    }
                    .padding(.trailing, 2)

                    ForEach(leftTabs) { item in
                        renderTabButton(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Spacer reserving the center notch area so tabs never overlap the notch
                Color.clear
                    .frame(width: notchCutoutWidth)

                // Right tabs (Terminal, VPN, etc.) + Work Mode Toggle + Quit App Cross Button
                HStack(spacing: 5) {
                    ForEach(rightTabs) { item in
                        renderTabButton(item)
                    }

                    workModeToggle

                    quitAppButton
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 8)

            // Center Notch cutout — perfectly centered in the window, exactly aligning with the physical notch!
            notchCenterCutout
        }
        .frame(height: max(viewModel.geometry.notchFrame.height, 30))
    }

    private var workModeToggle: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                let available = allTabItems.compactMap(\.builtInTab)
                viewModel.toggleWorkMode(availableTabs: available)
            }
        } label: {
            HStack(spacing: 3.5) {
                Image(systemName: viewModel.isWorkMode ? "briefcase.fill" : "person.crop.circle")
                    .font(.system(size: 9.5, weight: .bold))

                Text(viewModel.isWorkMode ? "Work" : "Personal")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .foregroundStyle(viewModel.isWorkMode ? Color.white : currentTheme.secondaryText)
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(
                Capsule()
                    .fill(
                        viewModel.isWorkMode
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color(red: 0.16, green: 0.48, blue: 0.98), Color(red: 0.10, green: 0.36, blue: 0.90)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            : AnyShapeStyle(Color.white.opacity(0.08))
                    )
            )
            .overlay(
                Capsule()
                    .stroke(
                        viewModel.isWorkMode
                            ? Color.blue.opacity(0.5)
                            : Color.white.opacity(0.12),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: viewModel.isWorkMode ? Color.blue.opacity(0.35) : Color.clear, radius: 4, y: 1)
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .help(viewModel.isWorkMode ? "Work Mode Active (Google Chat enabled) — Click for Personal Mode" : "Personal Mode Active (WhatsApp enabled) — Click for Work Mode")
    }

    private var quitAppButton: some View {
        Button {
            NSApp.terminate(nil)
        } label: {
            ZStack {
                Circle()
                    .fill(isQuitHovered ? Color(red: 0.95, green: 0.22, blue: 0.22) : Color.white.opacity(0.08))
                    .frame(width: 19, height: 19)

                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(isQuitHovered ? Color.white : currentTheme.secondaryText)
            }
            .frame(width: 22, height: 22)
            .contentShape(Circle())
            .overlay(
                Circle()
                    .stroke(isQuitHovered ? Color.red.opacity(0.8) : Color.white.opacity(0.12), lineWidth: 0.8)
            )
            .shadow(color: isQuitHovered ? Color.red.opacity(0.45) : Color.clear, radius: 4, y: 1)
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .onHover { isQuitHovered = $0 }
        .help("Quit NotchDeck (Stop Application)")
    }

    private var settingsTabBar: some View {
        ZStack(alignment: .center) {
            HStack(spacing: 0) {
                // Left top corner: Back button + Left settings category tabs
                HStack(spacing: 5) {
                    SettingsBackButton(isLight: currentTheme.isLight) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.isSettingsActive = false
                        }
                    }
                    .padding(.trailing, 2)

                    ForEach(leftSettingsCategories) { category in
                        settingsCategoryTabButton(category)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Center spacer
                Color.clear
                    .frame(width: notchCutoutWidth)

                // Right side: Right settings category tabs + Quit App Cross Button
                HStack(spacing: 5) {
                    ForEach(rightSettingsCategories) { category in
                        settingsCategoryTabButton(category)
                    }

                    quitAppButton
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 8)

            // Center Notch cutout — perfectly centered in the window
            notchCenterCutout
        }
        .frame(height: max(viewModel.geometry.notchFrame.height, 30))
    }

    private var leftSettingsCategories: [SettingsCategory] {
        [.general, .appearance]
    }

    private var rightSettingsCategories: [SettingsCategory] {
        [.shortcuts, .layout, .configSource]
    }

    private func settingsCategoryTabButton(_ category: SettingsCategory) -> some View {
        let isSelected = viewModel.selectedSettingsCategory == category
        return SettingsCategoryTabButton(category: category, isSelected: isSelected, isLight: currentTheme.isLight) {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.selectedSettingsCategory = category
            }
        }
    }

    @ViewBuilder
    private func renderTabButton(_ item: TabItemModel) -> some View {
        if let tab = item.builtInTab {
            if tab == .vpn, let vpnWidget = widgetRegistry.actionWidget(id: "vpn-status") ?? widgetRegistry.allActionWidgets.first(where: { $0.id.contains("vpn") }) {
                VPNTopBarToggle(widget: vpnWidget, isSelected: false, isLight: currentTheme.isLight) {
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
                    isSelected: viewModel.activeCustomTabId == nil && viewModel.activeTab == tab,
                    isLight: currentTheme.isLight
                ) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                        viewModel.activeCustomTabId = nil
                        viewModel.activeTab = tab
                    }
                }
            }
        } else {
            CustomTabButton(
                id: item.id,
                title: item.title,
                isSelected: viewModel.activeCustomTabId == item.id,
                isLight: currentTheme.isLight
            ) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                    viewModel.activeCustomTabId = item.id
                }
            }
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        if viewModel.isSettingsActive {
            NotchSettingsContentView(
                configManager: configManager,
                selectedCategory: $viewModel.selectedSettingsCategory
            )
        } else if let customId = viewModel.activeCustomTabId, let widget = widgetRegistry.widget(id: customId) {
            widget.expandedView()
                .padding(10)
        } else if let customId = viewModel.activeCustomTabId,
                   let widgetCfg = configManager.config.widgets.first(where: { $0.id == customId && ($0.type == "web" || $0.url != nil) }),
                   let urlString = widgetCfg.url ?? widgetCfg.path,
                   let url = URL(string: urlString) {
            DedicatedWebView(
                id: customId,
                title: widgetCfg.title.isEmpty ? customId.capitalized : widgetCfg.title,
                icon: widgetCfg.icon ?? "globe",
                brandColor: currentTheme.accent,
                defaultURL: url,
                userAgent: WebTabItem.userAgent(for: url),
                viewModel: viewModel
            )
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
            case .googlechat:
                DedicatedWebView(
                    id: "googlechat",
                    title: "Google Chat",
                    icon: "bubble.left.and.bubble.right.fill",
                    brandColor: Color(red: 0.0, green: 0.67, blue: 0.45),
                    defaultURL: URL(string: "https://accounts.google.com/AccountChooser?service=dynamite&Email=tanish.vashisth@cdadebate.com&continue=https://chat.google.com")!,
                    userAgent: WebTabItem.chromeUserAgent,
                    viewModel: viewModel
                )
            case .whatsapp:
                DedicatedWebView(
                    id: "whatsapp",
                    title: "WhatsApp",
                    icon: "message.fill",
                    brandColor: Color(red: 0.15, green: 0.78, blue: 0.42),
                    defaultURL: URL(string: "https://web.whatsapp.com")!,
                    userAgent: WebTabItem.chromeUserAgent,
                    viewModel: viewModel
                )
            case .gpt:
                DedicatedWebView(
                    id: "gpt",
                    title: "ChatGPT",
                    icon: "sparkles",
                    brandColor: Color(red: 0.06, green: 0.65, blue: 0.52),
                    defaultURL: URL(string: "https://chatgpt.com")!,
                    userAgent: WebTabItem.chromeUserAgent,
                    viewModel: viewModel
                )
            case .claude:
                DedicatedWebView(
                    id: "claude",
                    title: "Claude",
                    icon: "brain.head.profile",
                    brandColor: Color(red: 0.85, green: 0.44, blue: 0.28),
                    defaultURL: URL(string: "https://claude.ai")!,
                    userAgent: WebTabItem.chromeUserAgent,
                    viewModel: viewModel
                )
            case .slack:
                SlackTermView(viewModel: viewModel)
            case .shelf:
                ShelfView(shelfManager: shelfManager, copyOnDrop: configManager.config.general.copyOnDrop)
            case .terminal:
                TerminalView(viewModel: viewModel)
            case .holder:
                HolderView(holderManager: holderManager, viewModel: viewModel)
            case .web:
                WebDeckView(viewModel: viewModel)
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
    var isLight: Bool = false
    let action: () -> Void

    @State private var isHovered: Bool = false

    private var foregroundColor: Color {
        if isSelected {
            return isLight ? Color.black : .white
        } else if isHovered {
            return isLight ? Color.black.opacity(0.85) : .white.opacity(0.95)
        } else {
            return isLight ? Color.black.opacity(0.45) : .white.opacity(0.5)
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return isLight ? Color.black.opacity(0.12) : Color.white.opacity(0.18)
        } else if isHovered {
            return isLight ? Color.black.opacity(0.06) : Color.white.opacity(0.08)
        } else {
            return Color.clear
        }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: tab.iconName)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(foregroundColor)
                .frame(width: 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(backgroundColor)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .pointingHandCursor()
        .onHover { hovering in
            isHovered = hovering
        }
        .pointingHandCursor()
        .help(tab.displayName)
    }
}

private struct CustomTabButton: View {
    let id: String
    let title: String
    let isSelected: Bool
    var isLight: Bool = false
    let action: () -> Void

    @State private var isHovered: Bool = false

    private var foregroundColor: Color {
        if isSelected {
            return isLight ? Color.black : .white
        } else if isHovered {
            return isLight ? Color.black.opacity(0.85) : .white.opacity(0.95)
        } else {
            return isLight ? Color.black.opacity(0.45) : .white.opacity(0.5)
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return isLight ? Color.black.opacity(0.12) : Color.white.opacity(0.18)
        } else if isHovered {
            return isLight ? Color.black.opacity(0.06) : Color.white.opacity(0.08)
        } else {
            return Color.clear
        }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "square.dashed")
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(foregroundColor)
                .frame(width: 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(backgroundColor)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .pointingHandCursor()
        .onHover { hovering in
            isHovered = hovering
        }
        .pointingHandCursor()
        .help(title)
    }
}

private struct VPNTopBarToggle: View {
    @ObservedObject var widget: ActionWidget
    let isSelected: Bool
    var isLight: Bool = false
    let onToggle: () -> Void
    let onOpenTab: () -> Void

    @State private var isHovered: Bool = false

    private var isConnected: Bool {
        widget.status == .active
    }

    private var foregroundColor: Color {
        if isConnected {
            return Color.green
        } else if isHovered {
            return isLight ? Color.black.opacity(0.85) : .white
        } else {
            return isLight ? Color.black.opacity(0.45) : .white.opacity(0.5)
        }
    }

    private var backgroundColor: Color {
        if isConnected {
            return Color.green.opacity(0.18)
        } else if isHovered {
            return isLight ? Color.black.opacity(0.06) : Color.white.opacity(0.08)
        } else {
            return Color.clear
        }
    }

    var body: some View {
        Button(action: onToggle) {
            ZStack {
                if widget.isExecuting {
                    ProgressView()
                        .scaleEffect(0.55)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: isConnected ? "lock.shield.fill" : "lock.shield")
                        .font(.system(size: 12, weight: isConnected ? .semibold : .regular))
                        .foregroundStyle(foregroundColor)
                }
            }
            .frame(width: 28, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(backgroundColor)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .pointingHandCursor()
        .onHover { hovering in
            isHovered = hovering
        }
        .pointingHandCursor()
        .help(isConnected ? "VPN Connected (Click to disconnect)" : "VPN Disconnected (Click to connect)")
        .contextMenu {
            Button("Toggle VPN") {
                onToggle()
            }
            Button("Open VPN Details") {
                onOpenTab()
            }
        }
    }
}

private struct SettingsButton: View {
    var isLight: Bool = false
    let action: () -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovered ? (isLight ? Color.black : .white) : (isLight ? Color.black.opacity(0.55) : .white.opacity(0.65)))
                .frame(width: 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isHovered ? (isLight ? Color.black.opacity(0.10) : Color.white.opacity(0.16)) : (isLight ? Color.black.opacity(0.04) : Color.white.opacity(0.06)))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .pointingHandCursor()
        .onHover { hovering in
            isHovered = hovering
        }
        .pointingHandCursor()
        .help("Settings (⌘,)")
    }
}

private struct SettingsBackButton: View {
    var isLight: Bool = false
    let action: () -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isHovered ? (isLight ? Color.black : .white) : (isLight ? Color.black.opacity(0.7) : .white.opacity(0.85)))
                .frame(width: 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isHovered ? (isLight ? Color.black.opacity(0.12) : Color.white.opacity(0.18)) : (isLight ? Color.black.opacity(0.05) : Color.white.opacity(0.08)))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .pointingHandCursor()
        .onHover { hovering in
            isHovered = hovering
        }
        .pointingHandCursor()
        .help("Back to Dashboard (Esc)")
    }
}

private struct SettingsCategoryTabButton: View {
    let category: SettingsCategory
    let isSelected: Bool
    var isLight: Bool = false
    let action: () -> Void
    @State private var isHovered: Bool = false

    private var foregroundColor: Color {
        if isSelected {
            return isLight ? Color.black : .white
        } else if isHovered {
            return isLight ? Color.black.opacity(0.85) : .white.opacity(0.95)
        } else {
            return isLight ? Color.black.opacity(0.45) : .white.opacity(0.5)
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return isLight ? Color.black.opacity(0.12) : Color.white.opacity(0.18)
        } else if isHovered {
            return isLight ? Color.black.opacity(0.06) : Color.white.opacity(0.08)
        } else {
            return Color.clear
        }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: category.iconName)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(foregroundColor)
                .frame(width: 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(backgroundColor)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .pointingHandCursor()
        .onHover { hovering in
            isHovered = hovering
        }
        .pointingHandCursor()
        .help(category.title)
    }
}

// MARK: - Tab metadata

extension NotchTab {
    var displayName: String {
        switch self {
        case .home:       "Home"
        case .notes:      "Notes"
        case .googlechat: "Chat"
        case .whatsapp:   "WhatsApp"
        case .slack:      "Slack"
        case .shelf:      "Shelf"
        case .terminal:   "Terminal"
        case .holder:     "Holder"
        case .vpn:        "VPN"
        case .web:        "Web"
        case .gpt:        "ChatGPT"
        case .claude:     "Claude"
        }
    }

    var iconName: String {
        switch self {
        case .home:       "square.grid.2x2"
        case .notes:      "note.text"
        case .googlechat: "bubble.left.and.bubble.right.fill"
        case .whatsapp:   "message.fill"
        case .slack:      "number"
        case .shelf:      "tray.2"
        case .terminal:   "terminal"
        case .holder:     "macwindow.on.rectangle"
        case .vpn:        "lock.shield"
        case .web:        "globe"
        case .gpt:        "sparkles"
        case .claude:     "brain.head.profile"
        }
    }
}

// MARK: - Home Dashboard View

struct HomeDashboardView: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var mediaManager: MediaManager
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var widgetRegistry: WidgetRegistry

    private var activeHomeWidgets: [String] {
        let items = configManager.config.layout.home
        if items.isEmpty {
            return ["media", "processor", "ram"]
        }
        return items
    }

    var body: some View {
        Group {
            if activeHomeWidgets.count <= 3 {
                HStack(spacing: 10) {
                    ForEach(activeHomeWidgets, id: \.self) { widgetId in
                        homeTile(for: widgetId)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ],
                        spacing: 10
                    ) {
                        ForEach(activeHomeWidgets, id: \.self) { widgetId in
                            homeTile(for: widgetId)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func homeTile(for widgetId: String) -> some View {
        switch widgetId {
        case "media":
            MediaView(mediaManager: mediaManager)
        case "ram", "memory", "ram-status":
            RAMStatusTile()
        case "cpu", "processor", "cpu-status", "processing":
            CPUStatusTile()
        case "clock":
            ClockTile(calendarManager: calendarManager)
        case "calendar":
            CalendarWidgetTile(calendarManager: calendarManager)
        case "vpn", "vpn-status":
            if let vpn = widgetRegistry.actionWidget(id: "vpn-status") ?? widgetRegistry.allActionWidgets.first(where: { $0.id.contains("vpn") }) {
                VPNView(widget: vpn)
            }
        default:
            if let dynamicWidget = widgetRegistry.widget(id: widgetId) {
                dynamicWidget.expandedView()
            }
        }
    }
}

// MARK: - System Memory Info & Stats

struct SystemMemoryInfo: Sendable {
    let totalBytes: UInt64
    let usedBytes: UInt64
    let freeBytes: UInt64
    let appBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64

    var usedPercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100.0
    }

    var usedFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(usedBytes), countStyle: .memory)
    }

    var totalFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .memory)
    }

    var appFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(appBytes), countStyle: .memory)
    }

    var wiredFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(wiredBytes), countStyle: .memory)
    }

    var compressedFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(compressedBytes), countStyle: .memory)
    }

    var freeFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(freeBytes), countStyle: .memory)
    }

    var pressureColor: Color {
        if usedPercentage > 85 {
            return .red
        } else if usedPercentage > 70 {
            return .orange
        } else {
            return .green
        }
    }

    var pressureLabel: String {
        if usedPercentage > 85 {
            return "High"
        } else if usedPercentage > 70 {
            return "Moderate"
        } else {
            return "Normal"
        }
    }
}

enum SystemStats {
    static func getMemoryInfo() -> SystemMemoryInfo {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStats = vm_statistics64()
        let hostPort = mach_host_self()

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &size)
            }
        }

        let totalBytes = ProcessInfo.processInfo.physicalMemory

        guard result == KERN_SUCCESS else {
            return SystemMemoryInfo(
                totalBytes: totalBytes,
                usedBytes: 0,
                freeBytes: totalBytes,
                appBytes: 0,
                wiredBytes: 0,
                compressedBytes: 0
            )
        }

        var pageSize: vm_size_t = 0
        host_page_size(hostPort, &pageSize)
        let pSize = UInt64(pageSize)

        let active = UInt64(vmStats.active_count) * pSize
        let inactive = UInt64(vmStats.inactive_count) * pSize
        let wired = UInt64(vmStats.wire_count) * pSize
        let compressed = UInt64(vmStats.compressor_page_count) * pSize
        let free = UInt64(vmStats.free_count) * pSize

        let usedBytes = min(totalBytes, active + wired + compressed)
        let freeBytes = totalBytes > usedBytes ? totalBytes - usedBytes : free

        return SystemMemoryInfo(
            totalBytes: totalBytes,
            usedBytes: usedBytes,
            freeBytes: freeBytes,
            appBytes: active + inactive,
            wiredBytes: wired,
            compressedBytes: compressed
        )
    }

    static func getCPUInfo() -> SystemCPUInfo {
        CPUStatsTracker.shared.getCPUInfo()
    }
}

// MARK: - System CPU Info & Tracker

struct SystemCPUInfo: Sendable {
    let usagePercentage: Double
    let userPercentage: Double
    let systemPercentage: Double
    let idlePercentage: Double
    let coreCount: Int
    let chipBrand: String
    let load1m: Double
    let load5m: Double
    let load15m: Double

    var brandSubtitle: String {
        "\(chipBrand) • \(coreCount) Cores"
    }

    var userFormatted: String {
        String(format: "%.1f%%", userPercentage)
    }

    var systemFormatted: String {
        String(format: "%.1f%%", systemPercentage)
    }

    var idleFormatted: String {
        String(format: "%.1f%%", idlePercentage)
    }

    var loadFormatted: String {
        String(format: "%.2f", load1m)
    }

    var pressureColor: Color {
        if usagePercentage > 85 {
            return .red
        } else if usagePercentage > 60 {
            return .orange
        } else {
            return .cyan
        }
    }

    var pressureLabel: String {
        if usagePercentage > 85 {
            return "High"
        } else if usagePercentage > 60 {
            return "Moderate"
        } else {
            return "Normal"
        }
    }
}

final class CPUStatsTracker: @unchecked Sendable {
    static let shared = CPUStatsTracker()

    private var prevTicks: (user: UInt64, sys: UInt64, idle: UInt64, nice: UInt64)? = nil
    private var lastInfo: SystemCPUInfo? = nil
    private let lock = NSLock()

    private let chipBrand: String = {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 0 else { return "Apple Silicon" }
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &machine, &size, nil, 0)
        let brand = String(cString: machine).trimmingCharacters(in: .whitespacesAndNewlines)
        return brand.isEmpty ? "Apple Silicon" : brand
    }()

    private init() {
        prevTicks = sampleTicks()
    }

    private func sampleTicks() -> (user: UInt64, sys: UInt64, idle: UInt64, nice: UInt64)? {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var cpuLoad = host_cpu_load_info()
        let hostPort = mach_host_self()
        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(hostPort, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return (
            user: UInt64(cpuLoad.cpu_ticks.0),
            sys: UInt64(cpuLoad.cpu_ticks.1),
            idle: UInt64(cpuLoad.cpu_ticks.2),
            nice: UInt64(cpuLoad.cpu_ticks.3)
        )
    }

    func getCPUInfo() -> SystemCPUInfo {
        lock.lock()
        defer { lock.unlock() }

        let coreCount = ProcessInfo.processInfo.activeProcessorCount
        var loadavg = [Double](repeating: 0.0, count: 3)
        getloadavg(&loadavg, 3)

        guard let currentTicks = sampleTicks() else {
            return lastInfo ?? SystemCPUInfo(
                usagePercentage: 0,
                userPercentage: 0,
                systemPercentage: 0,
                idlePercentage: 100,
                coreCount: coreCount,
                chipBrand: chipBrand,
                load1m: loadavg[0],
                load5m: loadavg[1],
                load15m: loadavg[2]
            )
        }

        guard let prev = prevTicks else {
            prevTicks = currentTicks
            let initial = SystemCPUInfo(
                usagePercentage: 0,
                userPercentage: 0,
                systemPercentage: 0,
                idlePercentage: 100,
                coreCount: coreCount,
                chipBrand: chipBrand,
                load1m: loadavg[0],
                load5m: loadavg[1],
                load15m: loadavg[2]
            )
            lastInfo = initial
            return initial
        }

        let dUser = Double(currentTicks.user >= prev.user ? currentTicks.user - prev.user : 0)
        let dSys = Double(currentTicks.sys >= prev.sys ? currentTicks.sys - prev.sys : 0)
        let dIdle = Double(currentTicks.idle >= prev.idle ? currentTicks.idle - prev.idle : 0)
        let dNice = Double(currentTicks.nice >= prev.nice ? currentTicks.nice - prev.nice : 0)
        let total = dUser + dSys + dIdle + dNice

        prevTicks = currentTicks

        let userPct = total > 0 ? (dUser + dNice) / total * 100.0 : 0
        let sysPct = total > 0 ? dSys / total * 100.0 : 0
        let idlePct = total > 0 ? dIdle / total * 100.0 : 100.0
        let totalUsage = min(100.0, max(0.0, userPct + sysPct))

        let info = SystemCPUInfo(
            usagePercentage: totalUsage,
            userPercentage: userPct,
            systemPercentage: sysPct,
            idlePercentage: idlePct,
            coreCount: coreCount,
            chipBrand: chipBrand,
            load1m: loadavg[0],
            load5m: loadavg[1],
            load15m: loadavg[2]
        )
        lastInfo = info
        return info
    }
}

private func getBatteryInfo() -> (level: Int, isCharging: Bool)? {
    guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return nil }
    guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef], !sources.isEmpty else { return nil }
    for s in sources {
        guard let desc = IOPSGetPowerSourceDescription(snapshot, s)?.takeUnretainedValue() as? [String: Any] else { continue }
        if let cap = desc[kIOPSCurrentCapacityKey as String] as? Int {
            let charging = (desc[kIOPSIsChargingKey as String] as? Bool) ?? false
            return (cap, charging)
        }
    }
    return nil
}

// MARK: - RAM Status Tile

struct RAMStatusTile: View {
    @Environment(\.deckTheme) private var theme: DeckTheme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.5)) { _ in
            let mem = SystemStats.getMemoryInfo()

            VStack(alignment: .leading, spacing: 8) {
                // Top row: Header icon, title, and memory pressure pill
                HStack(alignment: .center) {
                    HStack(spacing: 5) {
                        Image(systemName: "memorychip")
                            .font(.system(size: 11))
                            .foregroundStyle(.purple.opacity(0.9))

                        Text("Memory (RAM)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.secondaryText)
                    }

                    Spacer()

                    // Pressure pill (Normal / Moderate / High)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(mem.pressureColor)
                            .frame(width: 5, height: 5)

                        Text(mem.pressureLabel)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(mem.pressureColor)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(mem.pressureColor.opacity(0.12)))
                }

                // Main Metric: Used RAM vs Total RAM
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text("\(Int(mem.usedPercentage))%")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.primaryText)

                        Text("\(mem.usedFormatted) / \(mem.totalFormatted)")
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.secondaryText)
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3.5)
                                .fill(theme.barTrack)
                                .frame(height: 5)

                            RoundedRectangle(cornerRadius: 3.5)
                                .fill(
                                    LinearGradient(
                                        colors: [mem.pressureColor.opacity(0.8), mem.pressureColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(4, geo.size.width * CGFloat(min(1.0, mem.usedPercentage / 100.0))), height: 5)
                        }
                    }
                    .frame(height: 5)
                    .padding(.top, 2)
                }

                Divider()
                    .overlay(theme.divider)

                // Breakdown: App Memory, Wired, Available
                VStack(spacing: 4) {
                    HStack {
                        HStack(spacing: 4) {
                            Circle().fill(Color.blue.opacity(0.8)).frame(width: 4, height: 4)
                            Text("App Memory")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.tertiaryText)
                        }
                        Spacer()
                        Text(mem.appFormatted)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.secondaryText)
                    }

                    HStack {
                        HStack(spacing: 4) {
                            Circle().fill(Color.orange.opacity(0.8)).frame(width: 4, height: 4)
                            Text("Wired Memory")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.tertiaryText)
                        }
                        Spacer()
                        Text(mem.wiredFormatted)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.secondaryText)
                    }

                    HStack {
                        HStack(spacing: 4) {
                            Circle().fill(Color.green.opacity(0.8)).frame(width: 4, height: 4)
                            Text("Available / Free")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.tertiaryText)
                        }
                        Spacer()
                        Text(mem.freeFormatted)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.secondaryText)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(11)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - CPU / Processor Status Tile

struct CPUStatusTile: View {
    @Environment(\.deckTheme) private var theme: DeckTheme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.5)) { _ in
            let cpu = SystemStats.getCPUInfo()

            VStack(alignment: .leading, spacing: 8) {
                // Top row: Header icon, title, and CPU pressure pill
                HStack(alignment: .center) {
                    HStack(spacing: 5) {
                        Image(systemName: "cpu")
                            .font(.system(size: 11))
                            .foregroundStyle(.cyan.opacity(0.9))

                        Text("Processor (CPU)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.secondaryText)
                    }

                    Spacer()

                    // Pressure pill (Normal / Moderate / High)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(cpu.pressureColor)
                            .frame(width: 5, height: 5)

                        Text(cpu.pressureLabel)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(cpu.pressureColor)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(cpu.pressureColor.opacity(0.12)))
                }

                // Main Metric: Usage % and Core / Chip info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text("\(Int(cpu.usagePercentage))%")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.primaryText)

                        Text(cpu.brandSubtitle)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.secondaryText)
                            .lineLimit(1)
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3.5)
                                .fill(theme.barTrack)
                                .frame(height: 5)

                            RoundedRectangle(cornerRadius: 3.5)
                                .fill(
                                    LinearGradient(
                                        colors: [cpu.pressureColor.opacity(0.8), cpu.pressureColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(4, geo.size.width * CGFloat(min(1.0, cpu.usagePercentage / 100.0))), height: 5)
                        }
                    }
                    .frame(height: 5)
                    .padding(.top, 2)
                }

                Divider()
                    .overlay(theme.divider)

                // Breakdown: User Processes, System / Kernel, Idle
                VStack(spacing: 4) {
                    HStack {
                        HStack(spacing: 4) {
                            Circle().fill(Color.cyan.opacity(0.8)).frame(width: 4, height: 4)
                            Text("User Processes")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.tertiaryText)
                        }
                        Spacer()
                        Text(cpu.userFormatted)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.secondaryText)
                    }

                    HStack {
                        HStack(spacing: 4) {
                            Circle().fill(Color.indigo.opacity(0.8)).frame(width: 4, height: 4)
                            Text("System / Kernel")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.tertiaryText)
                        }
                        Spacer()
                        Text(cpu.systemFormatted)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.secondaryText)
                    }

                    HStack {
                        HStack(spacing: 4) {
                            Circle().fill(Color.teal.opacity(0.8)).frame(width: 4, height: 4)
                            Text("Idle Capacity")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.tertiaryText)
                        }
                        Spacer()
                        Text(cpu.idleFormatted)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.secondaryText)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(11)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - Clock Tile

struct ClockTile: View {
    @ObservedObject var calendarManager: CalendarManager
    @Environment(\.deckTheme) private var theme: DeckTheme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
            let now = timeline.date
            let battery = getBatteryInfo()

            VStack(alignment: .leading, spacing: 10) {
                // Top row: Greeting and Battery Status
                HStack(alignment: .center) {
                    HStack(spacing: 5) {
                        Image(systemName: greetingIcon(for: now))
                            .font(.system(size: 11))
                            .foregroundStyle(.yellow.opacity(0.9))

                        Text(greeting(for: now))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.secondaryText)
                    }

                    Spacer()

                    if let b = battery {
                        HStack(spacing: 4) {
                            Image(systemName: b.isCharging ? "bolt.batteryblock.fill" : batteryIcon(for: b.level))
                                .font(.system(size: 10))
                                .foregroundStyle(b.isCharging ? Color.green : (b.level <= 20 ? Color.red : theme.secondaryText))

                            Text("\(b.level)%")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(theme.secondaryText)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(theme.inputBackground))
                    }
                }

                // Digital Clock Display (Live Seconds)
                VStack(alignment: .leading, spacing: 1) {
                    Text(now, format: .dateTime.hour().minute().second())
                        .font(.system(size: 26, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(theme.primaryText)

                    Text(now, format: .dateTime.weekday(.wide).day().month(.abbreviated).year())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                }

                Divider()
                    .overlay(theme.divider)

                // Schedule snapshot: next event or calendar indicator
                if let nextEvent = calendarManager.events.first {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.red.opacity(0.85))
                                .frame(width: 5, height: 5)

                            Text("Upcoming")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(theme.tertiaryText)
                                .textCase(.uppercase)
                        }

                        Text(nextEvent.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.primaryText)
                            .lineLimit(1)

                        Text(nextEvent.timeString)
                            .font(.system(size: 9))
                            .foregroundStyle(theme.secondaryText)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.tertiaryText)

                        Text("No upcoming events")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.tertiaryText)
                    }
                    .padding(.vertical, 2)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
        }
    }

    private func greeting(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12:  return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default:      return "Good Night"
        }
    }

    private func greetingIcon(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12:  return "sun.horizon.fill"
        case 12..<17: return "sun.max.fill"
        case 17..<22: return "sunset.fill"
        default:      return "moon.stars.fill"
        }
    }

    private func batteryIcon(for level: Int) -> String {
        switch level {
        case 0..<20:   return "battery.25"
        case 20..<50:  return "battery.50"
        case 50..<80:  return "battery.75"
        default:       return "battery.100"
        }
    }
}

// MARK: - Placeholder views

private struct TerminalPlaceholderView: View {
    var body: some View {
        placeholderLabel("Terminal — SwiftTerm integration (Phase 5)")
    }
}

private struct VPNPlaceholderView: View {
    @Environment(\.deckTheme) private var theme: DeckTheme

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.shield")
                .font(.system(size: 24))
                .foregroundStyle(theme.tertiaryText)
            Text("No VPN action widget defined in config.toml")
                .font(.system(size: 11))
                .foregroundStyle(theme.secondaryText)
            Text("Add an action widget with id = 'vpn-status' in config.toml")
                .font(.system(size: 9))
                .foregroundStyle(theme.tertiaryText)
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
    @Environment(\.deckTheme) private var theme: DeckTheme

    var isConnected: Bool {
        widget.status == .active
    }

    private var parsedIP: String? {
        for line in widget.lastOutput.components(separatedBy: .newlines) {
            if line.lowercased().contains("public ip:") {
                let parts = line.components(separatedBy: ":")
                if parts.count >= 2 {
                    let ip = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !ip.isEmpty && !ip.contains("{") { return ip }
                }
            }
        }
        return nil
    }

    private var parsedFirewall: String? {
        for line in widget.lastOutput.components(separatedBy: .newlines) {
            if line.lowercased().contains("firewall") {
                let parts = line.components(separatedBy: ":")
                if parts.count >= 2 {
                    let fw = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !fw.isEmpty && !fw.contains("{") { return fw }
                }
            }
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 28) {
            // Left: Status Shield
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isConnected ? Color.green.opacity(0.15) : theme.inputBackground)
                        .frame(width: 68, height: 68)

                    Image(systemName: isConnected ? "lock.shield.fill" : "lock.shield")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(isConnected ? Color.green : theme.secondaryText)
                }

                VStack(spacing: 2) {
                    Text(isConnected ? "Connected" : (widget.status == .checking ? "Connecting…" : "Disconnected"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isConnected ? Color.green : (widget.status == .checking ? Color.orange : theme.secondaryText))

                    if isConnected {
                        Text("Protected")
                            .font(.system(size: 10))
                            .foregroundStyle(.green.opacity(0.8))
                    } else {
                        Text("Unprotected")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.tertiaryText)
                    }
                }
            }
            .frame(width: 120)

            Divider()
                .overlay(theme.divider)
                .frame(height: 110)

            // Right: Info & Controls
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("VPN")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(theme.primaryText)

                    Spacer()

                    // Refresh button
                    Button {
                        Task { await widget.pollStatus() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.secondaryText)
                            .padding(6)
                            .background(Circle().fill(theme.inputBackground))
                    }
                    .buttonStyle(.plain)
                    .help("Refresh VPN status")
                }

                // Info items (clean badge pills)
                HStack(spacing: 10) {
                    if let ip = parsedIP {
                        HStack(spacing: 5) {
                            Image(systemName: "network")
                                .font(.system(size: 10))
                                .foregroundStyle(theme.secondaryText)
                            Text(ip)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(theme.primaryText)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(theme.inputBackground))
                    }

                    if let fw = parsedFirewall {
                        HStack(spacing: 5) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(fw.lowercased() == "on" ? Color.orange : theme.tertiaryText)
                            Text("Firewall: \(fw)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(theme.secondaryText)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(theme.inputBackground))
                    }
                }

                // Primary Action Button
                HStack(spacing: 12) {
                    Button {
                        if let toggleBtn = widget.config.buttons.first(where: { $0.label.lowercased().contains("toggle") }) {
                            Task { await widget.executeButton(toggleBtn) }
                        } else if isConnected, let disBtn = widget.config.buttons.first(where: { $0.label.lowercased().contains("dis") }) {
                            Task { await widget.executeButton(disBtn) }
                        } else if let connBtn = widget.config.buttons.first(where: { $0.label.lowercased().contains("connect") }) {
                            Task { await widget.executeButton(connBtn) }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if widget.isExecuting {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: isConnected ? "stop.fill" : "bolt.fill")
                                    .font(.system(size: 11))
                            }

                            Text(isConnected ? "Disconnect" : "Connect VPN")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isConnected ? Color.red.opacity(0.8) : Color.green.opacity(0.85))
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(widget.isExecuting)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
