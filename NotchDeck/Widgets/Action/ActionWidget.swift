// ActionWidget.swift
// Implements the action widget: polls status command, regex-matches state, and runs action buttons.

import AppKit
import Combine
import SwiftUI

enum ActionStatus: Equatable {
    case idle
    case checking
    case active
    case inactive
    case error(String)

    var color: Color {
        switch self {
        case .active: return .green
        case .inactive: return .secondary
        case .checking: return .orange
        case .idle: return .gray
        case .error: return .red
        }
    }

    var label: String {
        switch self {
        case .active: return "Connected"
        case .inactive: return "Disconnected"
        case .checking: return "Checking…"
        case .idle: return "Idle"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

@MainActor
final class ActionWidget: ObservableObject, NotchWidget {

    let id: String
    let title: String
    let iconName: String
    let config: WidgetConfig

    @Published private(set) var status: ActionStatus = .idle
    @Published private(set) var lastOutput: String = ""
    @Published private(set) var isExecuting: Bool = false
    @Published private(set) var lastUpdated: Date? = nil

    private var pollingTask: Task<Void, Never>?

    init(config: WidgetConfig) {
        self.id = config.id
        self.title = config.title.isEmpty ? config.id : config.title
        self.iconName = config.icon ?? "bolt.fill"
        self.config = config

        startPolling()
    }

    deinit {
        pollingTask?.cancel()
    }

    // MARK: - Polling

    func startPolling() {
        guard let statusCmd = config.statusCommand, !statusCmd.isEmpty else {
            self.status = .idle
            return
        }

        let interval = max(1, config.statusIntervalS)
        pollingTask?.cancel()

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollStatus()
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func pollStatus() async {
        guard let statusCmd = config.statusCommand, !statusCmd.isEmpty else { return }

        self.status = .checking
        do {
            let result = try await CommandRunner.run(statusCmd, timeout: 5.0)
            self.lastOutput = result.stdout.isEmpty ? result.stderr : result.stdout
            self.lastUpdated = Date()

            if let regexPattern = config.statusRegex, !regexPattern.isEmpty {
                let isMatch = self.lastOutput.range(of: regexPattern, options: .regularExpression) != nil
                self.status = isMatch ? .active : .inactive
            } else {
                self.status = (result.exitCode == 0) ? .active : .inactive
            }
        } catch {
            self.status = .error(error.localizedDescription)
            self.lastOutput = error.localizedDescription
        }
    }

    // MARK: - Execute Button

    func executeButton(_ button: WidgetButtonConfig) async {
        guard !isExecuting else { return }
        isExecuting = true
        defer { isExecuting = false }

        if let cmd = button.command, !cmd.isEmpty {
            _ = try? await CommandRunner.run(cmd, timeout: 15.0)
        } else if let script = button.applescript, !script.isEmpty {
            _ = try? await CommandRunner.runAppleScript(script)
        } else if let url = button.openUrl, !url.isEmpty {
            _ = CommandRunner.openURL(url)
        }

        // Brief delay for system state to update, then poll immediately
        try? await Task.sleep(nanoseconds: 500_000_000)
        await pollStatus()
    }

    // MARK: - NotchWidget Conformance

    func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 5) {
                Image(systemName: iconName)
                    .imageScale(.small)

                Circle()
                    .fill(status.color)
                    .frame(width: 6, height: 6)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
        )
    }

    func expandedView() -> AnyView {
        AnyView(
            ActionWidgetTile(widget: self)
        )
    }
}

// MARK: - Expanded Tile View

struct ActionWidgetTile: View {
    @ObservedObject var widget: ActionWidget

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: widget.iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)

                Text(widget.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                // Status indicator pill
                HStack(spacing: 5) {
                    Circle()
                        .fill(widget.status.color)
                        .frame(width: 7, height: 7)

                    Text(widget.status.label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(widget.status.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(widget.status.color.opacity(0.12))
                .cornerRadius(12)

                // Refresh button
                Button {
                    Task { await widget.pollStatus() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            // Output / details
            if !widget.lastOutput.isEmpty {
                Text(widget.lastOutput)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(6)
            }

            // Action Buttons
            if !widget.config.buttons.isEmpty {
                HStack(spacing: 8) {
                    ForEach(widget.config.buttons, id: \.label) { button in
                        Button {
                            Task { await widget.executeButton(button) }
                        } label: {
                            Text(button.label)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(buttonColor(for: button.label))
                                .foregroundStyle(.white)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(widget.isExecuting)
                    }

                    if widget.isExecuting {
                        ProgressView()
                            .scaleEffect(0.6)
                            .padding(.leading, 4)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func buttonColor(for label: String) -> Color {
        let lower = label.lowercased()
        if lower.contains("connect") || lower.contains("start") || lower.contains("up") {
            return .purple.opacity(0.8)
        } else if lower.contains("disconnect") || lower.contains("stop") || lower.contains("down") {
            return .red.opacity(0.7)
        }
        return .white.opacity(0.15)
    }
}
