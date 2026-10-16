// SettingsView.swift
// Settings window that reads and writes ~/.config/notchdeck/config.toml directly.
// The file is the single source of truth.

import AppKit
import SwiftUI

struct SettingsView: View {

    @ObservedObject var configManager: ConfigManager

    @State private var draftConfig: AppConfig = AppConfig()
    @State private var rawTomlText: String = ""
    @State private var rawSaveError: String? = nil
    @State private var showSaveSuccess: Bool = false
    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case appearance = "Appearance"
        case shortcuts = "Shortcuts"
        case layout = "Layout & Widgets"
        case configSource = "config.toml"
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)

            appearanceTab
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
                .tag(SettingsTab.appearance)

            shortcutsTab
                .tabItem { Label("Shortcuts", systemImage: "command") }
                .tag(SettingsTab.shortcuts)

            layoutTab
                .tabItem { Label("Layout", systemImage: "square.grid.2x2") }
                .tag(SettingsTab.layout)

            rawTomlTab
                .tabItem { Label("config.toml", systemImage: "doc.text") }
                .tag(SettingsTab.configSource)
        }
        .frame(minWidth: 580, minHeight: 460)
        .padding(16)
        .onAppear {
            syncFromConfigManager()
        }
        .onReceive(configManager.$config) { _ in
            syncFromConfigManager()
        }
    }

    private func syncFromConfigManager() {
        draftConfig = configManager.config
        if let contents = try? String(contentsOf: ConfigManager.configFile, encoding: .utf8) {
            rawTomlText = contents
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("Screen Target") {
                Picker("Screen", selection: $draftConfig.general.screen) {
                    Text("Built-in Display (default)").tag("builtin")
                    Text("Screen 0").tag("0")
                    Text("Screen 1").tag("1")
                }
            }

            Section("Hover & Peek Behavior") {
                Toggle("Hover to Open Dashboard", isOn: $draftConfig.general.hoverToExpand)
                Toggle("Hover to Peek (Compact Preview)", isOn: $draftConfig.general.hoverToPeek)
                HStack {
                    Text("Peek Delay")
                    Spacer()
                    Slider(value: Binding(
                        get: { Double(draftConfig.general.peekDelayMs) },
                        set: { draftConfig.general.peekDelayMs = Int($0) }
                    ), in: 50...500, step: 25)
                    .frame(width: 160)
                    Text("\(draftConfig.general.peekDelayMs) ms")
                        .monospacedDigit()
                        .frame(width: 60, alignment: .trailing)
                }
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: $draftConfig.general.launchAtLogin)
            }

            Section("Software Updates") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NotchDeck v0.1.0")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Powered by Sparkle updater")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Check for Updates…") {
                        UpdaterManager.shared.checkForUpdates()
                    }
                }
            }

            saveActionBar
        }
        .formStyle(.grouped)
    }

    // MARK: - Appearance Tab

    private var appearanceTab: some View {
        Form {
            Section("Theme") {
                Picker("Theme Style", selection: $draftConfig.appearance.theme) {
                    Text("Dark").tag("dark")
                    Text("Light").tag("light")
                }

                TextField("Accent Color (Hex)", text: $draftConfig.appearance.accent)
            }

            Section("Notch Dimensions") {
                HStack {
                    Text("Expanded Width")
                    Spacer()
                    Slider(value: Binding(
                        get: { Double(draftConfig.appearance.expandedWidth) },
                        set: { draftConfig.appearance.expandedWidth = Int($0) }
                    ), in: 480...1200, step: 10)
                    .frame(width: 160)
                    Text("\(draftConfig.appearance.expandedWidth) pt")
                        .monospacedDigit()
                        .frame(width: 70, alignment: .trailing)
                }

                HStack {
                    Text("Expanded Height")
                    Spacer()
                    Slider(value: Binding(
                        get: { Double(draftConfig.appearance.expandedHeight) },
                        set: { draftConfig.appearance.expandedHeight = Int($0) }
                    ), in: 180...600, step: 10)
                    .frame(width: 160)
                    Text("\(draftConfig.appearance.expandedHeight) pt")
                        .monospacedDigit()
                        .frame(width: 70, alignment: .trailing)
                }

                HStack {
                    Text("Corner Radius")
                    Spacer()
                    Slider(value: Binding(
                        get: { Double(draftConfig.appearance.cornerRadius) },
                        set: { draftConfig.appearance.cornerRadius = Int($0) }
                    ), in: 8...36, step: 1)
                    .frame(width: 160)
                    Text("\(draftConfig.appearance.cornerRadius) pt")
                        .monospacedDigit()
                        .frame(width: 70, alignment: .trailing)
                }
            }

            saveActionBar
        }
        .formStyle(.grouped)
    }

    // MARK: - Shortcuts Tab

    private var shortcutsTab: some View {
        Form {
            Section("Global Hotkeys") {
                LabeledContent("Toggle Notch") {
                    TextField("e.g. cmd+shift+space", text: $draftConfig.shortcuts.toggle)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }

                LabeledContent("Quick Note") {
                    TextField("e.g. cmd+shift+n", text: $draftConfig.shortcuts.quickNote)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }
            }

            Section("Supported Modifiers & Keys") {
                Text("Modifiers: cmd, shift, opt, ctrl\nKeys: space, return, escape, tab, a-z, 0-9, f1-f12")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            saveActionBar
        }
        .formStyle(.grouped)
    }

    // MARK: - Layout & Widgets Tab

    private var layoutTab: some View {
        Form {
            Section("Expanded Tabs Order") {
                Text(draftConfig.layout.tabs.joined(separator: " → "))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            Section("Home Tab Widgets") {
                Text(draftConfig.layout.home.joined(separator: ", "))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            Section("Configured Widgets (\(draftConfig.widgets.count))") {
                if draftConfig.widgets.isEmpty {
                    Text("No custom widgets defined in config.toml")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(draftConfig.widgets, id: \.id) { widget in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(widget.title.isEmpty ? widget.id : widget.title)
                                    .font(.headline)
                                Text("ID: \(widget.id) • Type: \(widget.type)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let shortcut = widget.shortcut {
                                Text(shortcut)
                                    .font(.caption.monospaced())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }

            Section {
                Button("Edit Widgets in config.toml") {
                    selectedTab = .configSource
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Raw TOML Tab (File as Source of Truth)

    private var rawTomlTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ConfigManager.configFile.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let error = configManager.configError {
                        Label(error.localizedDescription ?? "Invalid TOML", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if let err = rawSaveError {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        Label("Config valid • Hot-reload active", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                Button("Reveal in Finder") {
                    configManager.revealConfigFileInFinder()
                }

                Button("Open in External Editor") {
                    configManager.openConfigFileInDefaultEditor()
                }
            }

            TextEditor(text: $rawTomlText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )

            HStack {
                Button("Revert to Disk") {
                    syncFromConfigManager()
                    rawSaveError = nil
                }

                Spacer()

                if showSaveSuccess {
                    Text("Saved & reloaded!")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }

                Button("Save config.toml") {
                    saveRawToml()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private var saveActionBar: some View {
        Section {
            HStack {
                if showSaveSuccess {
                    Text("Saved to config.toml")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                Spacer()
                Button("Save Changes") {
                    saveDraftConfig()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func saveDraftConfig() {
        do {
            try configManager.save(config: draftConfig)
            rawSaveError = nil
            triggerSaveFeedback()
        } catch {
            rawSaveError = error.localizedDescription
        }
    }

    private func saveRawToml() {
        do {
            // Validate first
            _ = try TOMLParser.parse(rawTomlText)
            try configManager.writeRaw(rawTomlText)
            configManager.load()
            rawSaveError = nil
            triggerSaveFeedback()
        } catch let err as ConfigError {
            rawSaveError = err.localizedDescription
        } catch {
            rawSaveError = error.localizedDescription
        }
    }

    private func triggerSaveFeedback() {
        withAnimation {
            showSaveSuccess = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                showSaveSuccess = false
            }
        }
    }
}
