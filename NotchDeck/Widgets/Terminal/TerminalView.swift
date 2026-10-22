// TerminalView.swift
// Multi-session terminal dashboard for the expanded notch.
// Supports multi-session management, quick controls, and in-notch full expand/zoom.

import AppKit
import SwiftUI

struct TerminalView: View {
    @ObservedObject var manager = TerminalManager.shared
    var viewModel: NotchViewModel? = nil
    @Environment(\.deckTheme) private var theme: DeckTheme

    var body: some View {
        VStack(spacing: 0) {
            // Tab header
            sessionTabBar
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 6)

            Divider()
                .overlay(theme.divider)

            // Active terminal view
            if let active = manager.activeSession {
                TerminalRepresentable(terminalView: active.terminalView)
                    .id(active.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)
                    .padding(8)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.system(size: 28))
                        .foregroundStyle(theme.tertiaryText)
                    Text("No active terminal sessions")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sessionTabBar: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(manager.sessions) { session in
                        sessionTab(session)
                    }

                    // Add new shell session button
                    Button {
                        manager.createNewShellSession()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(theme.secondaryText)
                            .padding(6)
                            .background(theme.inputBackground)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("New Shell Session")
                }
            }

            Spacer()

            if let active = manager.activeSession {
                HStack(spacing: 6) {
                    // In-notch Zoom Toggle Button (expands the notch deck to large dimensions)
                    if let vm = viewModel {
                        Button {
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                                vm.toggleTerminalZoom()
                            }
                        } label: {
                            Image(systemName: vm.isTerminalZoomed ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(vm.isTerminalZoomed ? theme.primaryText : theme.secondaryText)
                                .frame(width: 24, height: 22)
                                .background(vm.isTerminalZoomed ? theme.tabSelected : theme.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                        .help(vm.isTerminalZoomed ? "Shrink Notch Deck" : "Expand Notch Deck")
                    }

                    if active.isRunning {
                        Button {
                            active.restart()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(theme.secondaryText)
                                .padding(4)
                                .background(theme.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                        .help("Restart Session")

                        Button {
                            active.terminate()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.red.opacity(0.85))
                                .padding(4)
                                .background(theme.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                        .help("Stop Session")
                    } else {
                        Button {
                            active.start()
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.green)
                                .padding(4)
                                .background(theme.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                        .help("Start Session")
                    }
                }
            }
        }
    }

    private func sessionTab(_ session: TerminalSession) -> some View {
        let isSelected = session.id == manager.selectedSessionId

        return Button {
            manager.selectedSessionId = session.id
        } label: {
            HStack(spacing: 6) {
                // Status dot
                Circle()
                    .fill(statusColor(for: session))
                    .frame(width: 6, height: 6)

                Text(session.title)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? theme.primaryText : theme.secondaryText)

                if session.id != "default" {
                    Button {
                        manager.closeSession(id: session.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? theme.tabSelected : theme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func statusColor(for session: TerminalSession) -> Color {
        if session.isRunning {
            return .green
        } else if let code = session.exitCode, code != 0 {
            return .red
        } else {
            return .gray.opacity(0.6)
        }
    }
}
