// TerminalView.swift
// Multi-session terminal dashboard for the expanded notch.
// Supports multi-session management, quick controls, and full-screen modal zoom.

import AppKit
import SwiftUI

struct TerminalView: View {
    @ObservedObject var manager = TerminalManager.shared
    @ObservedObject var zoomModal = TerminalZoomModalController.shared
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

            // Active terminal view or zoom placeholder
            if let active = manager.activeSession {
                if zoomModal.isPresented && zoomModal.session?.id == active.id {
                    VStack(spacing: 10) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.35))
                        Text("Shell is open in full screen mode")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                        Button("Exit Full Screen") {
                            zoomModal.dismiss()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TerminalRepresentable(terminalView: active.terminalView)
                        .id(active.id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(8)
                }
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
                    // Fullscreen Zoom Button
                    Button {
                        zoomModal.present(session: active)
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 22)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .help("Open in Full Screen (Click outside to close)")

                    if active.isRunning {
                        Button {
                            active.restart()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(4)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                        .help("Restart Session")

                        Button {
                            active.terminate()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.red.opacity(0.85))
                                .padding(4)
                                .background(Color.white.opacity(0.06))
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
                                .foregroundColor(.green)
                                .padding(4)
                                .background(Color.white.opacity(0.06))
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

// MARK: - Full Screen Zoom Modal Controller & View

final class ModalPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    var cardRect: CGRect = .zero
    var onBackdropClick: (() -> Void)?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            if !cardRect.isEmpty && !cardRect.contains(event.locationInWindow) {
                onBackdropClick?()
                return // Swallow click so it closes the modal only
            }
        }
        super.sendEvent(event)
    }
}

@MainActor
final class TerminalZoomModalController: NSObject, ObservableObject {
    static let shared = TerminalZoomModalController()

    @Published var isPresented: Bool = false
    @Published var session: TerminalSession?

    var onDismiss: (() -> Void)?

    private var window: ModalPanel?

    func present(session: TerminalSession) {
        self.session = session
        self.isPresented = true

        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.frame

        let cardWidth = min(screenFrame.width * 0.88, 1040)
        let cardHeight = min(screenFrame.height * 0.82, 660)
        let cardRect = CGRect(
            x: (screenFrame.width - cardWidth) / 2,
            y: (screenFrame.height - cardHeight) / 2,
            width: cardWidth,
            height: cardHeight
        )

        let panel: ModalPanel
        if let existing = self.window {
            panel = existing
            panel.setFrame(screenFrame, display: true)
        } else {
            panel = ModalPanel(
                contentRect: screenFrame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = false
            panel.acceptsMouseMovedEvents = true
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .stationary,
                .ignoresCycle
            ]
            self.window = panel
        }

        panel.cardRect = cardRect
        panel.onBackdropClick = { [weak self] in
            self?.dismiss()
        }

        let rootView = TerminalZoomModalView(
            controller: self,
            cardWidth: cardWidth,
            cardHeight: cardHeight
        )
        panel.contentView = NSHostingView(rootView: rootView)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        guard isPresented else { return }
        isPresented = false
        session = nil
        window?.orderOut(nil)
        onDismiss?()
    }
}

struct TerminalZoomModalView: View {
    @ObservedObject var controller: TerminalZoomModalController
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    var body: some View {
        ZStack {
            // Darkened backdrop covering the whole screen — clicking outside closes the modal!
            Color.black.opacity(0.60)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    controller.dismiss()
                }

            // Centered Terminal Modal Card
            if let session = controller.session {
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 8) {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))

                        Text(session.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)

                        Circle()
                            .fill(session.isRunning ? Color.green : Color.red)
                            .frame(width: 7, height: 7)

                        Spacer()

                        Text("Click outside to exit")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.45))

                        Button {
                            controller.dismiss()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Exit Full Screen")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .help("Exit Full Screen")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.45))

                    Divider().overlay(Color.white.opacity(0.12))

                    // Full size terminal view
                    TerminalRepresentable(terminalView: session.terminalView)
                        .id("zoom_\(session.id)")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(10)
                }
                .frame(width: cardWidth, height: cardHeight)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(NSColor.windowBackgroundColor).opacity(0.97))
                        .shadow(color: .black.opacity(0.7), radius: 36, x: 0, y: 18)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
