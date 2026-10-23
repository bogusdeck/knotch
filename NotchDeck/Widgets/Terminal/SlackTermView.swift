// SlackTermView.swift
// Dedicated Slack tab view powered by slack-term inside a persistent SwiftTerm session.
// Includes quick controls, config editor launcher, in-notch expand, and optional web fallback.

import AppKit
import SwiftUI

// MARK: - SlackTermManager

@MainActor
final class SlackTermManager: ObservableObject {
    static let shared = SlackTermManager()

    @Published var session: TerminalSession?
    @Published var isWebMode: Bool = false

    func ensureStarted() {
        guard session == nil else { return }

        let s = TerminalSession(
            id: "slack-term",
            title: "Slack",
            command: "slack-term",
            cwd: "~"
        )
        s.start()
        self.session = s
    }

    func restart() {
        session?.terminate()
        let s = TerminalSession(
            id: "slack-term",
            title: "Slack",
            command: "slack-term",
            cwd: "~"
        )
        s.start()
        self.session = s
    }

    func openConfigFile() {
        let configPath = NSString(string: "~/.config/slack-term/config").expandingTildeInPath
        let url = URL(fileURLWithPath: configPath)
        if !FileManager.default.fileExists(atPath: configPath) {
            try? FileManager.default.createDirectory(atPath: (configPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: configPath, contents: "{\n  \"slack_token\": \"\"\n}\n".data(using: .utf8))
        }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - SlackTermView

struct SlackTermView: View {
    @ObservedObject var manager = SlackTermManager.shared
    var viewModel: NotchViewModel? = nil
    @Environment(\.deckTheme) private var theme: DeckTheme

    private let slackColor = Color(red: 0.88, green: 0.15, blue: 0.44)

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 8) {
                // Brand Badge
                HStack(spacing: 6) {
                    Image(systemName: "number")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(slackColor)

                    Text("Slack")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.primaryText)

                    // Mode indicator badge
                    Text(manager.isWebMode ? "web" : "term")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(manager.isWebMode ? theme.secondaryText : slackColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(manager.isWebMode ? theme.inputBackground : slackColor.opacity(0.15))
                        )

                    // Process status dot
                    if !manager.isWebMode, let s = manager.session {
                        Circle()
                            .fill(s.isRunning ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                            .help(s.isRunning ? "slack-term running" : "slack-term exited")
                    }
                }

                Spacer()

                // Mode toggle (Terminal vs Web)
                HStack(spacing: 2) {
                    Button {
                        manager.isWebMode = false
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "terminal")
                                .font(.system(size: 9.5))
                            Text("Terminal")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(!manager.isWebMode ? theme.tabSelected : Color.clear)
                        )
                        .foregroundStyle(!manager.isWebMode ? theme.primaryText : theme.tertiaryText)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()

                    Button {
                        manager.isWebMode = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "globe")
                                .font(.system(size: 9.5))
                            Text("Web")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(manager.isWebMode ? theme.tabSelected : Color.clear)
                        )
                        .foregroundStyle(manager.isWebMode ? theme.primaryText : theme.tertiaryText)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.inputBackground.opacity(0.6))
                )

                // Actions for Terminal mode
                if !manager.isWebMode {
                    Button {
                        manager.openConfigFile()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 10))
                            Text("Config")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3.5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(theme.inputBackground.opacity(0.6)))
                        .foregroundStyle(theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    .help("Edit ~/.config/slack-term/config")

                    Button {
                        manager.restart()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 24, height: 24)
                            .background(RoundedRectangle(cornerRadius: 6).fill(theme.inputBackground.opacity(0.6)))
                            .foregroundStyle(theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    .help("Restart slack-term")
                }

                // In-notch Zoom / Full-screen Toggle
                if let vm = viewModel {
                    Button {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                            vm.toggleTerminalZoom()
                        }
                    } label: {
                        Image(systemName: vm.isTerminalZoomed ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(vm.isTerminalZoomed ? theme.tabSelected : theme.inputBackground.opacity(0.6))
                            )
                            .foregroundStyle(vm.isTerminalZoomed ? theme.primaryText : theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    .help(vm.isTerminalZoomed ? "Shrink View" : "Zoom View")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)

            Divider()
                .overlay(theme.divider)

            // Content Area
            if manager.isWebMode {
                DedicatedWebView(
                    id: "slack",
                    title: "Slack",
                    icon: "number",
                    brandColor: slackColor,
                    defaultURL: URL(string: "https://app.slack.com/client")!,
                    userAgent: WebTabItem.chromeUserAgent,
                    viewModel: viewModel
                )
            } else {
                ZStack {
                    if let session = manager.session {
                        TerminalRepresentable(terminalView: session.terminalView)
                            .id(session.id)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(4)
                    } else {
                        VStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Initializing slack-term...")
                                .font(.system(size: 11))
                                .foregroundStyle(theme.tertiaryText)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.2))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            manager.ensureStarted()
        }
    }
}
