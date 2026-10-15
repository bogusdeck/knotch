// ShellWidget.swift
// Implements the shell widget: displays the stdout of a command refreshed on an interval.

import Combine
import SwiftUI

@MainActor
final class ShellWidget: ObservableObject, NotchWidget {

    let id: String
    let title: String
    let command: String
    let interval: Int

    @Published private(set) var output: String = "Loading…"
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var lastUpdated: Date? = nil
    @Published private(set) var hasError: Bool = false

    private var pollingTask: Task<Void, Never>?

    init(config: WidgetConfig) {
        self.id = config.id
        self.title = config.title.isEmpty ? config.id : config.title
        self.command = config.command ?? "echo 'No command specified'"
        self.interval = max(1, config.intervalS)

        startPolling()
    }

    init(id: String, title: String, command: String, interval: Int = 30) {
        self.id = id
        self.title = title
        self.command = command
        self.interval = max(1, interval)

        startPolling()
    }

    deinit {
        pollingTask?.cancel()
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.executeCommand()
                try? await Task.sleep(nanoseconds: UInt64(self?.interval ?? 30) * 1_000_000_000)
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func executeCommand() async {
        isRunning = true
        defer { isRunning = false }

        do {
            let result = try await CommandRunner.run(command, timeout: 10.0)
            self.output = result.stdout.isEmpty ? result.stderr : result.stdout
            self.hasError = (result.exitCode != 0)
            self.lastUpdated = Date()
        } catch {
            self.output = error.localizedDescription
            self.hasError = true
            self.lastUpdated = Date()
        }
    }

    // MARK: - NotchWidget Conformance

    func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 6) {
                Image(systemName: "terminal.fill")
                    .imageScale(.small)
                    .foregroundStyle(.purple)

                Text(output.components(separatedBy: .newlines).first ?? title)
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
        )
    }

    func expandedView() -> AnyView {
        AnyView(
            ShellWidgetTile(widget: self)
        )
    }
}

// MARK: - Shell Widget Tile View

struct ShellWidgetTile: View {
    @ObservedObject var widget: ShellWidget

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.purple)

                Text(widget.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                if widget.isRunning {
                    ProgressView()
                        .scaleEffect(0.6)
                }

                Button {
                    Task { await widget.executeCommand() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                Text(widget.output)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(widget.hasError ? .red.opacity(0.8) : .white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(maxHeight: 120)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)

            if let lastUpdated = widget.lastUpdated {
                Text("Updated \(lastUpdated, style: .time)")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.35))
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
}
