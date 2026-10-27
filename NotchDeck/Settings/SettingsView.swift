// SettingsView.swift
// Native settings experience for NotchDeck.
// Provides both NotchSettingsContentView (rendered in-place inside the notch panel)
// and SettingsView (for standalone window usage).
// Reads and writes ~/.config/notchdeck/config.toml as the single source of truth.

import AppKit
import SwiftUI

// MARK: - Settings Category

enum SettingsCategory: String, CaseIterable, Identifiable, Sendable {
    case general = "General"
    case appearance = "Appearance"
    case shortcuts = "Shortcuts"
    case layout = "Layout"
    case configSource = "config.toml"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .shortcuts: "Shortcuts"
        case .layout: "Layout"
        case .configSource: "config.toml"
        }
    }

    var iconName: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintpalette"
        case .shortcuts: "command"
        case .layout: "square.grid.2x2"
        case .configSource: "doc.text"
        }
    }
}

// MARK: - In-Notch Settings Content View

struct NotchSettingsContentView: View {
    @ObservedObject var configManager: ConfigManager
    @Binding var selectedCategory: SettingsCategory

    @State private var draftConfig: AppConfig = AppConfig()
    @State private var rawTomlText: String = ""
    @State private var rawSaveError: String? = nil
    @State private var showSaveSuccess: Bool = false
    @State private var successMessage: String = "Saved to config.toml"

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 12) {
                switch selectedCategory {
                case .general:
                    generalSection
                case .appearance:
                    appearanceSection
                case .shortcuts:
                    shortcutsSection
                case .layout:
                    layoutSection
                case .configSource:
                    rawTomlSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .onAppear {
            syncFromConfigManager()
        }
        .onReceive(configManager.$config) { _ in
            syncFromConfigManager()
        }
        .onChange(of: draftConfig.appearance) { _, newAppearance in
            configManager.updateAppearanceLive(newAppearance)
        }
    }

    private func syncFromConfigManager() {
        draftConfig = configManager.config
        if let contents = try? String(contentsOf: ConfigManager.configFile, encoding: .utf8) {
            rawTomlText = contents
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        VStack(spacing: 12) {
            SettingsCard(title: "Display & Screen", icon: "display") {
                HStack {
                    Text("Target Screen")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Picker("", selection: $draftConfig.general.screen) {
                        Text("Built-in Display").tag("builtin")
                        Text("External Screen 0").tag("0")
                        Text("External Screen 1").tag("1")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 170)
                }
            }

            SettingsCard(title: "Hover & Peek Behavior", icon: "hand.point.up.left") {
                VStack(spacing: 10) {
                    Toggle(isOn: $draftConfig.general.hoverToExpand) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hover to Expand")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("Automatically open dashboard when hovering the notch")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                    Divider().overlay(Color.white.opacity(0.08))

                    Toggle(isOn: $draftConfig.general.hoverToPeek) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hover to Peek")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("Show compact media/battery preview before full expand")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                    Divider().overlay(Color.white.opacity(0.08))

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Peek Delay")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("Delay before compact peek activates")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        Slider(value: Binding(
                            get: { Double(draftConfig.general.peekDelayMs) },
                            set: { draftConfig.general.peekDelayMs = Int($0) }
                        ), in: 50...500, step: 25)
                        .frame(width: 140)
                        Text("\(draftConfig.general.peekDelayMs) ms")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 55, alignment: .trailing)
                    }
                }
            }

            SettingsCard(title: "Startup & Updates", icon: "sparkles") {
                VStack(spacing: 10) {
                    Toggle(isOn: $draftConfig.general.launchAtLogin) {
                        Text("Launch at Login")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                    Divider().overlay(Color.white.opacity(0.08))

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Knotch v0.1.0")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            Text("Automatic updates powered by Sparkle")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        Button("Check for Updates…") {
                            UpdaterManager.shared.checkForUpdates()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            saveActionBar
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        VStack(spacing: 12) {
            SettingsCard(title: "Theme & Accent", icon: "paintpalette") {
                VStack(spacing: 10) {
                    HStack {
                        Text("Theme Style")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Picker("", selection: $draftConfig.appearance.theme) {
                            Text("Dark (HUD)").tag("dark")
                            Text("Light (Frosted)").tag("light")
                            Text("System Match").tag("auto")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }

                    Divider().overlay(Color.white.opacity(0.08))

                    HStack {
                        Text("Accent Color")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Circle()
                            .fill(Color(hex: draftConfig.appearance.accent) ?? .accentColor)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                        TextField("#7C5CFF", text: $draftConfig.appearance.accent)
                            .font(.system(size: 11, design: .monospaced))
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                            .frame(width: 90)
                    }
                }
            }

            SettingsCard(title: "Notch Dimensions", icon: "aspectratio") {
                VStack(spacing: 10) {
                    Toggle(isOn: $draftConfig.appearance.dynamicSizing) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dynamic Section Dimensions")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("Adapts notch width and height dynamically based on each tab's content")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .toggleStyle(.switch)

                    if draftConfig.appearance.dynamicSizing {
                        Divider().overlay(Color.white.opacity(0.08))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tailored size per section:")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                                tabSizeBadge(label: "Home", size: "640 × 260")
                                tabSizeBadge(label: "Terminal", size: "720 × 380")
                                tabSizeBadge(label: "Notes", size: "680 × 380")
                                tabSizeBadge(label: "Holder", size: "660 × 330")
                                tabSizeBadge(label: "VPN", size: "540 × 230")
                                tabSizeBadge(label: "Settings", size: "660 × 420")
                            }
                        }
                    } else {
                        Divider().overlay(Color.white.opacity(0.08))

                        HStack {
                            Text("Expanded Width")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            Slider(value: Binding(
                                get: { Double(draftConfig.appearance.expandedWidth) },
                                set: { draftConfig.appearance.expandedWidth = Int($0) }
                            ), in: 480...1200, step: 10)
                            .frame(width: 160)
                            Text("\(draftConfig.appearance.expandedWidth) pt")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(width: 60, alignment: .trailing)
                        }

                        Divider().overlay(Color.white.opacity(0.08))

                        HStack {
                            Text("Expanded Height")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            Slider(value: Binding(
                                get: { Double(draftConfig.appearance.expandedHeight) },
                                set: { draftConfig.appearance.expandedHeight = Int($0) }
                            ), in: 180...600, step: 10)
                            .frame(width: 160)
                            Text("\(draftConfig.appearance.expandedHeight) pt")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(width: 60, alignment: .trailing)
                        }
                    }

                    Divider().overlay(Color.white.opacity(0.08))

                    HStack {
                        Text("Corner Radius")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Slider(value: Binding(
                            get: { Double(draftConfig.appearance.cornerRadius) },
                            set: { draftConfig.appearance.cornerRadius = Int($0) }
                        ), in: 8...36, step: 1)
                        .frame(width: 160)
                        Text("\(draftConfig.appearance.cornerRadius) pt")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            }

            saveActionBar
        }
    }

    private func tabSizeBadge(label: String, size: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Text(size)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.06))
        .cornerRadius(6)
    }

    // MARK: - Shortcuts Section

    private var shortcutsSection: some View {
        VStack(spacing: 12) {
            SettingsCard(title: "Global Hotkeys", icon: "command") {
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Toggle Notch")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("Global shortcut to expand or collapse Knotch")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        TextField("cmd+shift+space", text: $draftConfig.shortcuts.toggle)
                            .font(.system(size: 11, design: .monospaced))
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                            .frame(width: 160)
                    }

                    Divider().overlay(Color.white.opacity(0.08))

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quick Note")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("Open directly to note taking input")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        TextField("cmd+shift+n", text: $draftConfig.shortcuts.quickNote)
                            .font(.system(size: 11, design: .monospaced))
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                            .frame(width: 160)
                    }
                }
            }

            SettingsCard(title: "Supported Shortcut Keys", icon: "info.circle") {
                Text("Modifiers: cmd, shift, opt, ctrl\nKeys: space, return, escape, tab, a-z, 0-9, f1-f12")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            saveActionBar
        }
    }

    // MARK: - Layout Section

    private var layoutSection: some View {
        VStack(spacing: 12) {
            SettingsCard(title: "Work Mode & Tabs", icon: "briefcase") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Work Mode Enabled by Default", isOn: $draftConfig.layout.workMode)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .toggleStyle(.switch)

                    Text("When Work Mode is active, work apps (Google Chat) are displayed and personal apps (WhatsApp) are hidden. You can also toggle this instantly at any time via the Work/Personal pill in the drawer top header.")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            SettingsCard(title: "Active Notch Tabs", icon: "tray.2") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tabs currently enabled in top bar:")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                    HStack(spacing: 6) {
                        ForEach(draftConfig.layout.tabs, id: \.self) { tabName in
                            Text(tabName)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(6)
                        }
                    }
                }
            }

            SettingsCard(title: "Home Dashboard Cards", icon: "square.grid.2x2") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Active Cards (\(draftConfig.layout.home.count))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("Cards are displayed side-by-side as square tiles on Home")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                        }

                        Spacer()

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                draftConfig.layout.home = ["media", "cpu", "ram"]
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                Text("3 Square Cards")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Quickly preset to Media + CPU + RAM 3-card square layout")
                    }

                    // Currently active chips with ordering & removal
                    if draftConfig.layout.home.isEmpty {
                        Text("No cards active. Please enable at least one card below.")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange.opacity(0.8))
                    } else {
                        HStack(spacing: 6) {
                            ForEach(Array(draftConfig.layout.home.enumerated()), id: \.offset) { index, widgetName in
                                HStack(spacing: 4) {
                                    Text("\(index + 1).")
                                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color.accentColor)

                                    Text(widgetDisplayName(for: widgetName))
                                        .font(.system(size: 10.5, weight: .medium))
                                        .foregroundStyle(.white)

                                    Button {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            draftConfig.layout.home.removeAll { $0 == widgetName }
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3.5)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(6)
                            }
                        }
                    }

                    Divider().overlay(Color.white.opacity(0.08))

                    Text("Toggle Available Cards:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))

                    // List of available widgets
                    VStack(spacing: 6) {
                        ForEach(availableHomeWidgetOptions) { option in
                            let isEnabled = draftConfig.layout.home.contains(option.id) ||
                                (option.id == "cpu" && (draftConfig.layout.home.contains("processor") || draftConfig.layout.home.contains("cpu-status") || draftConfig.layout.home.contains("processing"))) ||
                                (option.id == "ram" && (draftConfig.layout.home.contains("memory") || draftConfig.layout.home.contains("ram-status")))

                            HStack {
                                Image(systemName: option.icon)
                                    .font(.system(size: 12))
                                    .foregroundStyle(isEnabled ? Color.accentColor : Color.white.opacity(0.4))
                                    .frame(width: 18)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(option.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.white.opacity(isEnabled ? 0.95 : 0.6))
                                    Text(option.description)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.white.opacity(0.4))
                                }

                                Spacer()

                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        if isEnabled {
                                            draftConfig.layout.home.removeAll { id in
                                                id == option.id ||
                                                (option.id == "cpu" && (id == "processor" || id == "cpu-status" || id == "processing")) ||
                                                (option.id == "ram" && (id == "memory" || id == "ram-status"))
                                            }
                                        } else {
                                            draftConfig.layout.home.append(option.id)
                                        }
                                    }
                                } label: {
                                    Text(isEnabled ? "Active" : "+ Add")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(isEnabled ? Color.white : Color.white.opacity(0.7))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2.5)
                                        .background(isEnabled ? Color.accentColor : Color.white.opacity(0.1))
                                        .cornerRadius(5)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }

            SettingsCard(title: "Custom Widgets (\(draftConfig.widgets.count))", icon: "gearshape.2") {
                if draftConfig.widgets.isEmpty {
                    Text("No custom widgets defined in config.toml")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                } else {
                    VStack(spacing: 6) {
                        ForEach(draftConfig.widgets, id: \.id) { widget in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(widget.title.isEmpty ? widget.id : widget.title)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.9))
                                    Text("ID: \(widget.id) • Type: \(widget.type)")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                Spacer()
                                if let shortcut = widget.shortcut {
                                    Text(shortcut)
                                        .font(.system(size: 9, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button {
                    selectedCategory = .configSource
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "pencil.line")
                        Text("Edit Layout & Widgets in config.toml")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            saveActionBar
        }
    }

    // MARK: - Raw TOML Section

    private var rawTomlSection: some View {
        VStack(spacing: 10) {
            SettingsCard(title: "Configuration File", icon: "doc.text") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(ConfigManager.configFile.path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        if let error = configManager.configError {
                            Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.red)
                        } else if let err = rawSaveError {
                            Label(err, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.red)
                        } else {
                            Label("Hot-reload active", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.green)
                        }
                    }

                    HStack(spacing: 8) {
                        Button("Reveal in Finder") {
                            configManager.revealConfigFileInFinder()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Open in External Editor") {
                            configManager.openConfigFileInDefaultEditor()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Spacer()

                        Button("Revert to Disk") {
                            syncFromConfigManager()
                            rawSaveError = nil
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                TextEditor(text: $rawTomlText)
                    .font(.system(size: 11, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.black.opacity(0.45))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .frame(minHeight: 110, maxHeight: 180)

                HStack {
                    if showSaveSuccess {
                        Label(successMessage, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    } else if let err = rawSaveError {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button("Save config.toml") {
                        saveRawToml()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Save Bar

    private var saveActionBar: some View {
        HStack {
            if showSaveSuccess {
                Label(successMessage, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.green)
                    .transition(.opacity)
            } else if let err = rawSaveError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
            Spacer()
            Button("Save Changes") {
                saveDraftConfig()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(.top, 4)
    }

    // MARK: - Save Handlers

    private func saveDraftConfig() {
        do {
            try configManager.save(config: draftConfig)
            rawSaveError = nil
            triggerSaveFeedback("Saved to config.toml")
        } catch {
            rawSaveError = error.localizedDescription
        }
    }

    private func saveRawToml() {
        do {
            _ = try TOMLParser.parse(rawTomlText)
            try configManager.writeRaw(rawTomlText)
            configManager.load()
            rawSaveError = nil
            triggerSaveFeedback("Saved & reloaded config.toml")
        } catch let err as ConfigError {
            rawSaveError = err.localizedDescription
        } catch {
            rawSaveError = error.localizedDescription
        }
    }

    private func triggerSaveFeedback(_ message: String) {
        successMessage = message
        withAnimation {
            showSaveSuccess = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation {
                showSaveSuccess = false
            }
        }
    }
}

// MARK: - Settings Card Helper

private struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String?
    @ViewBuilder let content: () -> Content

    init(title: String, icon: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            content()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Standalone Window Wrapper

struct SettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var selectedCategory: SettingsCategory = .general

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(SettingsCategory.allCases) { cat in
                    Button {
                        selectedCategory = cat
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: cat.iconName)
                            Text(cat.title)
                        }
                        .font(.system(size: 12, weight: selectedCategory == cat ? .semibold : .regular))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedCategory == cat ? Color.white.opacity(0.15) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.2))

            Divider().overlay(Color.white.opacity(0.1))

            NotchSettingsContentView(configManager: configManager, selectedCategory: $selectedCategory)
        }
        .frame(minWidth: 580, minHeight: 460)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Home Widget Options

struct HomeWidgetOption: Identifiable, Sendable {
    let id: String
    let name: String
    let icon: String
    let description: String
}

private let availableHomeWidgetOptions: [HomeWidgetOption] = [
    HomeWidgetOption(id: "media", name: "Media Player", icon: "opticaldisc", description: "Spotify / Music playback & Vinyl mode"),
    HomeWidgetOption(id: "cpu", name: "Processor (CPU)", icon: "cpu", description: "Live CPU usage %, cores, load stats"),
    HomeWidgetOption(id: "ram", name: "Memory (RAM)", icon: "memorychip", description: "RAM usage %, pressure & breakdown"),
    HomeWidgetOption(id: "clock", name: "Clock & Date", icon: "clock", description: "Digital clock, date & battery info"),
    HomeWidgetOption(id: "calendar", name: "Calendar", icon: "calendar", description: "Next upcoming event & schedule"),
    HomeWidgetOption(id: "vpn", name: "VPN Status", icon: "lock.shield", description: "VPN tunnel status & quick toggle")
]

private func widgetDisplayName(for id: String) -> String {
    switch id {
    case "media": return "Media"
    case "cpu", "processor", "cpu-status", "processing": return "Processor"
    case "ram", "memory", "ram-status": return "Memory"
    case "clock": return "Clock"
    case "calendar": return "Calendar"
    case "vpn", "vpn-status": return "VPN"
    default: return id
    }
}

