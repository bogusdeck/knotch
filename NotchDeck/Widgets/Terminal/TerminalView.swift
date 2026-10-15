// TerminalView.swift
// Multi-session terminal dashboard for the expanded notch.

import SwiftUI

struct TerminalView: View {
    @ObservedObject var manager = TerminalManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Tab header
            sessionTabBar
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 6)

            Divider()
                .opacity(0.3)

            // Active terminal view
            if let active = manager.activeSession {
                TerminalRepresentable(terminalView: active.terminalView)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(8)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("No active terminal sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("New Shell Session")
                }
            }

            Spacer()

            if let active = manager.activeSession {
                HStack(spacing: 6) {
                    if active.isRunning {
                        Button {
                            active.restart()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Restart Session")

                        Button {
                            active.terminate()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .help("Stop Session")
                    } else {
                        Button {
                            active.start()
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.green)
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
                    .foregroundColor(isSelected ? .primary : .secondary)

                if session.id != "default" {
                    Button {
                        manager.closeSession(id: session.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
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
