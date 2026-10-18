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
    @State private var isExpandedDropTargeted: Bool = false

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
        let configured = configManager.config.layout.tabs
        var items: [TabItemModel] = []
        for tabId in configured {
            switch tabId {
            case "home":
                items.append(TabItemModel(id: "home", title: "Home", iconName: "square.grid.2x2", builtInTab: .home))
            case "notes":
                items.append(TabItemModel(id: "notes", title: "Notes", iconName: "note.text", builtInTab: .notes))
            case "shelf":
                items.append(TabItemModel(id: "shelf", title: "Shelf", iconName: "tray.2", builtInTab: .shelf))
            case "terminal":
                items.append(TabItemModel(id: "terminal", title: "Terminal", iconName: "terminal", builtInTab: .terminal))
            case "vpn":
                items.append(TabItemModel(id: "vpn", title: "VPN", iconName: "lock.shield", builtInTab: .vpn))
            default:
                if let widget = widgetRegistry.widget(id: tabId) {
                    items.append(TabItemModel(id: widget.id, title: widget.title, iconName: "square.dashed", builtInTab: nil))
                }
            }
        }
        return items
    }

    private var leftTabs: [TabItemModel] {
        let split = min(3, allTabItems.count)
        return Array(allTabItems.prefix(split))
    }

    private var rightTabs: [TabItemModel] {
        let split = min(3, allTabItems.count)
        return Array(allTabItems.dropFirst(split))
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

    @ViewBuilder
    private var tabBar: some View {
        if viewModel.isSettingsActive {
            settingsTabBar
        } else {
            normalTabBar
        }
    }

    private var normalTabBar: some View {
        HStack(spacing: 0) {
            // Left top corner: Settings button on the leftmost side + Left tabs (Home, Notes, Shelf)
            HStack(spacing: 5) {
                SettingsButton {
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

            // Center Notch cutout — matches hardware notch, clicking closes!
            notchCenterCutout

            // Right tabs (Terminal, VPN, etc.)
            HStack(spacing: 4) {
                ForEach(rightTabs) { item in
                    renderTabButton(item)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .frame(height: max(viewModel.geometry.notchFrame.height, 30))
    }

    private var settingsTabBar: some View {
        HStack(spacing: 0) {
            // Left top corner: Back button + Left settings category tabs
            HStack(spacing: 5) {
                SettingsBackButton {
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

            // Center Notch cutout — matches hardware notch, clicking closes!
            notchCenterCutout

            // Right side: Right settings category tabs
            HStack(spacing: 4) {
                ForEach(rightSettingsCategories) { category in
                    settingsCategoryTabButton(category)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 8)
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
        return SettingsCategoryTabButton(category: category, isSelected: isSelected) {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.selectedSettingsCategory = category
            }
        }
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
        if viewModel.isSettingsActive {
            NotchSettingsContentView(
                configManager: configManager,
                selectedCategory: $viewModel.selectedSettingsCategory
            )
        } else if let customId = viewModel.activeCustomTabId, let widget = widgetRegistry.widget(id: customId) {
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
                TerminalView(viewModel: viewModel)
            case .holder:
                HolderView(holderManager: holderManager)
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
            Image(systemName: tab.iconName)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : (isHovered ? .white.opacity(0.95) : .white.opacity(0.5)))
                .frame(width: 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(
                            isSelected
                                ? Color.white.opacity(0.18)
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
        .help(tab.displayName)
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
            Image(systemName: "square.dashed")
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : (isHovered ? .white.opacity(0.95) : .white.opacity(0.5)))
                .frame(width: 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(
                            isSelected
                                ? Color.white.opacity(0.18)
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
        .help(title)
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
            ZStack {
                if widget.isExecuting {
                    ProgressView()
                        .scaleEffect(0.55)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: isConnected ? "lock.shield.fill" : "lock.shield")
                        .font(.system(size: 12, weight: isConnected ? .semibold : .regular))
                        .foregroundStyle(isConnected ? Color.green : (isHovered ? .white : .white.opacity(0.5)))
                }
            }
            .frame(width: 28, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 7)
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
    let action: () -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovered ? .white : .white.opacity(0.65))
                .frame(width: 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isHovered ? Color.white.opacity(0.16) : Color.white.opacity(0.06))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .help("Settings (⌘,)")
    }
}

private struct SettingsBackButton: View {
    let action: () -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isHovered ? .white : .white.opacity(0.85))
                .frame(width: 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .help("Back to Dashboard (Esc)")
    }
}

private struct SettingsCategoryTabButton: View {
    let category: SettingsCategory
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: category.iconName)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : (isHovered ? .white.opacity(0.95) : .white.opacity(0.5)))
                .frame(width: 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(
                            isSelected
                                ? Color.white.opacity(0.18)
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
        .help(category.title)
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
        case .holder:   "Holder"
        case .vpn:      "VPN"
        }
    }

    var iconName: String {
        switch self {
        case .home:     "square.grid.2x2"
        case .notes:    "note.text"
        case .shelf:    "tray.2"
        case .terminal: "terminal"
        case .holder:   "macwindow.on.rectangle"
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

    private var isRAMWidgetEnabled: Bool {
        configManager.config.layout.home.contains("ram") ||
        configManager.config.layout.home.contains("memory") ||
        configManager.config.layout.home.contains("ram-status")
    }

    private var isCPUWidgetEnabled: Bool {
        configManager.config.layout.home.contains("cpu") ||
        configManager.config.layout.home.contains("processor") ||
        configManager.config.layout.home.contains("cpu-status") ||
        configManager.config.layout.home.contains("processing")
    }

    private var isClockWidgetEnabled: Bool {
        configManager.config.layout.home.contains("clock")
    }

    private var rightWidgetIds: [String] {
        var ids: [String] = []
        for id in configManager.config.layout.home {
            if id == "ram" || id == "memory" || id == "ram-status" {
                if !ids.contains("ram") { ids.append("ram") }
            } else if id == "cpu" || id == "processor" || id == "cpu-status" || id == "processing" {
                if !ids.contains("cpu") { ids.append("cpu") }
            } else if id == "clock" {
                if !ids.contains("clock") { ids.append("clock") }
            }
        }
        return ids
    }

    private var leftWidgetIds: [String] {
        let items = configManager.config.layout.home.filter {
            $0 != "clock" && $0 != "ram" && $0 != "memory" && $0 != "ram-status" &&
            $0 != "cpu" && $0 != "processor" && $0 != "cpu-status" && $0 != "processing"
        }
        return items.isEmpty ? ["media"] : items
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Left Column: Media Player, Calendar, other cards
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(leftWidgetIds, id: \.self) { widgetId in
                        homeTile(for: widgetId)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxWidth: .infinity)

            // Right Column: RAM / CPU / Clock cards
            if !rightWidgetIds.isEmpty {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(rightWidgetIds, id: \.self) { rightId in
                            switch rightId {
                            case "ram":
                                RAMStatusTile()
                            case "cpu":
                                CPUStatusTile()
                            case "clock":
                                ClockTile(calendarManager: calendarManager)
                            default:
                                EmptyView()
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(width: 220)
            }
        }
        .padding(14)
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
                            .foregroundStyle(.white.opacity(0.65))
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
                            .foregroundStyle(.white)

                        Text("\(mem.usedFormatted) / \(mem.totalFormatted)")
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3.5)
                                .fill(Color.white.opacity(0.08))
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
                    .overlay(Color.white.opacity(0.08))

                // Breakdown: App Memory, Wired, Available
                VStack(spacing: 4) {
                    HStack {
                        HStack(spacing: 4) {
                            Circle().fill(Color.blue.opacity(0.8)).frame(width: 4, height: 4)
                            Text("App Memory")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        Text(mem.appFormatted)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    HStack {
                        HStack(spacing: 4) {
                            Circle().fill(Color.orange.opacity(0.8)).frame(width: 4, height: 4)
                            Text("Wired Memory")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        Text(mem.wiredFormatted)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    HStack {
                        HStack(spacing: 4) {
                            Circle().fill(Color.green.opacity(0.8)).frame(width: 4, height: 4)
                            Text("Available / Free")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        Text(mem.freeFormatted)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

// MARK: - CPU / Processor Status Tile

struct CPUStatusTile: View {
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
                            .foregroundStyle(.white.opacity(0.65))
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
                            .foregroundStyle(.white)

                        Text(cpu.brandSubtitle)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3.5)
                                .fill(Color.white.opacity(0.08))
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
                    .overlay(Color.white.opacity(0.08))

                // Breakdown: User Processes, System / Kernel, Idle
                VStack(spacing: 4) {
                    HStack {
                        HStack(spacing: 4) {
                            Circle().fill(Color.cyan.opacity(0.8)).frame(width: 4, height: 4)
                            Text("User Processes")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        Text(cpu.userFormatted)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    HStack {
                        HStack(spacing: 4) {
                            Circle().fill(Color.indigo.opacity(0.8)).frame(width: 4, height: 4)
                            Text("System / Kernel")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        Text(cpu.systemFormatted)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    HStack {
                        HStack(spacing: 4) {
                            Circle().fill(Color.teal.opacity(0.8)).frame(width: 4, height: 4)
                            Text("Idle Capacity")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        Text(cpu.idleFormatted)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

// MARK: - Clock Tile

struct ClockTile: View {
    @ObservedObject var calendarManager: CalendarManager

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
                            .foregroundStyle(.white.opacity(0.65))
                    }

                    Spacer()

                    if let b = battery {
                        HStack(spacing: 4) {
                            Image(systemName: b.isCharging ? "bolt.batteryblock.fill" : batteryIcon(for: b.level))
                                .font(.system(size: 10))
                                .foregroundStyle(b.isCharging ? Color.green : (b.level <= 20 ? Color.red : Color.white.opacity(0.6)))

                            Text("\(b.level)%")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                    }
                }

                // Digital Clock Display (Live Seconds)
                VStack(alignment: .leading, spacing: 1) {
                    Text(now, format: .dateTime.hour().minute().second())
                        .font(.system(size: 26, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text(now, format: .dateTime.weekday(.wide).day().month(.abbreviated).year())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Divider()
                    .overlay(Color.white.opacity(0.08))

                // Schedule snapshot: next event or calendar indicator
                if let nextEvent = calendarManager.events.first {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.red.opacity(0.85))
                                .frame(width: 5, height: 5)

                            Text("Upcoming")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.45))
                                .textCase(.uppercase)
                        }

                        Text(nextEvent.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(nextEvent.timeString)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.35))

                        Text("No upcoming events")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
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
                        .fill(isConnected ? Color.green.opacity(0.15) : Color.white.opacity(0.06))
                        .frame(width: 68, height: 68)

                    Image(systemName: isConnected ? "lock.shield.fill" : "lock.shield")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(isConnected ? Color.green : Color.white.opacity(0.45))
                }

                VStack(spacing: 2) {
                    Text(isConnected ? "Connected" : (widget.status == .checking ? "Connecting…" : "Disconnected"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isConnected ? Color.green : (widget.status == .checking ? Color.orange : Color.white.opacity(0.6)))

                    if isConnected {
                        Text("Protected")
                            .font(.system(size: 10))
                            .foregroundStyle(.green.opacity(0.8))
                    } else {
                        Text("Unprotected")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
            }
            .frame(width: 120)

            Divider()
                .overlay(Color.white.opacity(0.1))
                .frame(height: 110)

            // Right: Info & Controls
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("VPN")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    // Refresh button
                    Button {
                        Task { await widget.pollStatus() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(6)
                            .background(Circle().fill(Color.white.opacity(0.06)))
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
                                .foregroundStyle(.white.opacity(0.5))
                            Text(ip)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                    }

                    if let fw = parsedFirewall {
                        HStack(spacing: 5) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(fw.lowercased() == "on" ? Color.orange : Color.white.opacity(0.4))
                            Text("Firewall: \(fw)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
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
