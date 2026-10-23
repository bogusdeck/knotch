// NotchRootView.swift
// The top-level SwiftUI view mounted inside the NSPanel.
// Renders the correct sub-view for each state (collapsed / peek / expanded)
// and handles file drag-hover expansion onto the notch.

import SwiftUI
import UniformTypeIdentifiers

struct NotchRootView: View {

    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var notesManager: NotesManager
    @ObservedObject var shelfManager: ShelfManager
    @ObservedObject var holderManager: HolderManager
    @ObservedObject var mediaManager: MediaManager
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var widgetRegistry: WidgetRegistry

    @State private var isDragHoveringNotch: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            // Background shape that grows/shrinks with state
            notchBackground

            // Content layer
            contentLayer

            // Config error banner overlay
            if let error = viewModel.configError {
                ErrorBannerView(error: error) {
                    viewModel.configError = nil
                }
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(999)
            }
        }
        // Fill the entire panel frame
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Transparent outside the background shape
        .background(.clear)
        // Drag hover target on the notch — expands on hover, adds items on drop
        .onDrop(of: DropURLHelper.supportedDropTypes, isTargeted: $isDragHoveringNotch) { providers in
            handleDrop(providers: providers)
        }
        .onChange(of: isDragHoveringNotch) { _, isHovering in
            viewModel.isDraggingOverNotch = isHovering
            if isHovering {
                if viewModel.state != .expanded {
                    viewModel.requestExpand()
                }
                if configManager.config.layout.tabs.contains("holder") {
                    viewModel.activeTab = .holder
                } else if configManager.config.layout.tabs.contains("shelf") {
                    viewModel.activeTab = .shelf
                }
            }
        }
        // ESC to collapse
        .onKeyPress(.escape) {
            viewModel.requestCollapse()
            return .handled
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: viewModel.state)
        .environment(\.deckTheme, currentTheme)
    }

    // MARK: - Background shape

    private var currentTheme: DeckTheme {
        DeckTheme.current(
            theme: configManager.config.appearance.theme,
            accentHex: configManager.config.appearance.accent
        )
    }

    private var notchBackground: some View {
        let cornerR = CGFloat(configManager.config.appearance.cornerRadius)
        let theme = currentTheme
        let isCollapsed = viewModel.state == .collapsed
        let isCollapsedNotch = viewModel.geometry.hasNotch && isCollapsed
        let showWhatsAppGlow = viewModel.hasWhatsAppNotification && isCollapsed
        let showBorder = !isCollapsed
        let borderStrokeColor = theme.isLight ? theme.outerBorder : Color.white.opacity(0.12)
        let shadowColor = !isCollapsed ? Color.black.opacity(0.42) : Color.clear
        let notchW = viewModel.geometry.notchFrame.width
        let notchH = viewModel.geometry.notchFrame.height
        let collapsedW = showWhatsAppGlow ? notchW + 10 : notchW
        let collapsedH = showWhatsAppGlow ? notchH + 4 : notchH

        return ZStack(alignment: .top) {
            if showWhatsAppGlow {
                // WhatsApp Notification: Pure Electric Green Pill (Zero black fill outside the notch)
                NotchShape(
                    hasNotch: viewModel.geometry.hasNotch,
                    state: viewModel.state,
                    cornerRadius: 15
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.83, blue: 0.45),
                            Color(red: 0.22, green: 0.98, blue: 0.52),
                            Color(red: 0.15, green: 0.83, blue: 0.45)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color(red: 0.15, green: 0.83, blue: 0.45).opacity(0.95), radius: 6, x: 0, y: 2)
                .shadow(color: Color(red: 0.22, green: 0.98, blue: 0.52).opacity(0.6), radius: 10, x: 0, y: 2)
                .frame(
                    width: isCollapsedNotch ? collapsedW : nil,
                    height: isCollapsedNotch ? collapsedH : nil
                )
            } else {
                NotchShape(
                    hasNotch: viewModel.geometry.hasNotch,
                    state: viewModel.state,
                    cornerRadius: cornerR
                )
                .fill(isCollapsedNotch ? Color.black : theme.background)
                .frame(
                    width: isCollapsedNotch ? collapsedW : nil,
                    height: isCollapsedNotch ? collapsedH : nil
                )
            }

            if showBorder {
                NotchShape(
                    hasNotch: viewModel.geometry.hasNotch,
                    state: viewModel.state,
                    cornerRadius: cornerR
                )
                .stroke(borderStrokeColor, lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .shadow(color: shadowColor, radius: 18, y: 8)
        .ignoresSafeArea()
    }

    // MARK: - Content

    @ViewBuilder
    private var contentLayer: some View {
        ZStack(alignment: .top) {
            // Keep ExpandedView mounted in the window hierarchy so that WebKit audio
            // (Spotify, YouTube, web media) and active sessions (WhatsApp, Slack)
            // NEVER get paused or disconnected when the notch collapses!
            ExpandedView(
                viewModel: viewModel,
                configManager: configManager,
                notesManager: notesManager,
                shelfManager: shelfManager,
                holderManager: holderManager,
                mediaManager: mediaManager,
                calendarManager: calendarManager,
                widgetRegistry: widgetRegistry
            )
            .opacity(viewModel.state == .expanded ? 1 : 0)
            .allowsHitTesting(viewModel.state == .expanded)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            if viewModel.state == .collapsed {
                collapsedView
                    .transition(.opacity)
            } else if viewModel.state == .peek {
                PeekView(viewModel: viewModel, mediaManager: mediaManager)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.requestExpand()
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                        removal: .opacity
                    ))
            }
        }
    }

    private var collapsedView: some View {
        let notchW = viewModel.hasWhatsAppNotification ? viewModel.geometry.notchFrame.width + 10 : viewModel.geometry.notchFrame.width
        let notchH = viewModel.hasWhatsAppNotification ? viewModel.geometry.notchFrame.height + 4 : viewModel.geometry.notchFrame.height

        return ZStack {
            // Solid hit target restricted strictly to the notch frame
            Color.black.opacity(0.001)
                .frame(width: notchW, height: notchH)
                .contentShape(Rectangle())

            HStack(spacing: 6) {
                if TerminalManager.shared.hasRunningServers {
                    collapsedServerStatusDot
                        .transition(.opacity)
                }

                if let vpn = widgetRegistry.actionWidget(id: "vpn-status"), vpn.status == .active {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }

                if viewModel.hasWhatsAppNotification {
                    HStack(spacing: 3) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(.white)
                        if viewModel.whatsAppUnreadCount > 0 {
                            Text("\(viewModel.whatsAppUnreadCount)")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(Color.black.opacity(0.3)))
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                if let media = mediaManager.currentMedia, media.isPlaying {
                    collapsedMediaAccessory(media)
                        .transition(.opacity)
                }
            }
            .frame(width: notchW, height: notchH)
            .padding(.horizontal, 10)
        }
        .frame(width: notchW, height: notchH)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.requestExpand()
        }
        .contextMenu {
            if viewModel.hasWhatsAppNotification {
                Button("Clear WhatsApp Notification") {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) {
                        viewModel.whatsAppUnreadCount = 0
                    }
                    NotificationCenter.default.post(name: .whatsAppUnreadCountChanged, object: nil, userInfo: ["count": 0])
                }
            } else {
                Button("Simulate WhatsApp Notification (Test Glow)") {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) {
                        viewModel.whatsAppUnreadCount = 1
                    }
                    NotificationCenter.default.post(name: .whatsAppUnreadCountChanged, object: nil, userInfo: ["count": 1])
                }
            }
            Divider()
            Button("Expand Notch") {
                viewModel.requestExpand()
            }
            Divider()
            Button("Quit NotchDeck") {
                NSApp.terminate(nil)
            }
        }
    }

    // MARK: - Collapsed Media Accessory

    private func collapsedMediaAccessory(_ media: MediaItem) -> some View {
        HStack(spacing: 5) {
            if let artwork = media.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 14, height: 14)
                    .cornerRadius(3)
            } else if let urlStr = media.artworkUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 9))
                            .foregroundStyle(media.brandColor)
                    }
                }
                .frame(width: 14, height: 14)
                .cornerRadius(3)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 9))
                    .foregroundStyle(media.brandColor)
            }

            AudioWaveView(isPlaying: true, color: .purple)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.8))
        .cornerRadius(6)
        .padding(.trailing, 2)
    }

    // MARK: - Collapsed Server Status Dot

    private var collapsedServerStatusDot: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 5, height: 5)
            .shadow(color: .green.opacity(0.8), radius: 2)
            .padding(.leading, 8)
            .padding(.bottom, 3)
            .frame(maxHeight: .infinity, alignment: .bottomLeading)
    }

    // MARK: - Drop Handling

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        DropURLHelper.extractURLs(from: providers) { urls in
            for url in urls {
                let isApp = url.pathExtension.lowercased() == "app" || url.path.hasSuffix(".app")
                if isApp || self.configManager.config.layout.tabs.contains("holder") {
                    self.holderManager.addItem(from: url)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        self.viewModel.activeTab = .holder
                    }
                } else {
                    self.shelfManager.addItem(
                        from: url,
                        copyOnDrop: self.configManager.config.general.copyOnDrop
                    )
                }
            }
        }
        return true
    }
}
