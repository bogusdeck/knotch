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
        .onDrop(of: [UTType.fileURL], isTargeted: $isDragHoveringNotch) { providers in
            handleDrop(providers: providers)
        }
        .onChange(of: isDragHoveringNotch) { _, isHovering in
            if isHovering {
                if viewModel.state != .expanded {
                    viewModel.requestExpand()
                }
                viewModel.activeTab = .shelf
            }
        }
        // ESC to collapse
        .onKeyPress(.escape) {
            viewModel.state = .collapsed
            return .handled
        }
    }

    // MARK: - Background shape

    private var notchBackground: some View {
        NotchShape(
            hasNotch: viewModel.geometry.hasNotch,
            state: viewModel.state
        )
        .fill(.black)
        .frame(
            width: viewModel.state == .collapsed ? viewModel.geometry.notchFrame.width : nil,
            height: viewModel.state == .collapsed ? viewModel.geometry.notchFrame.height : nil,
            alignment: .top
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if viewModel.state == .collapsed || viewModel.state == .peek {
                viewModel.requestExpand()
            }
        }
        .animation(
            .spring(response: 0.35, dampingFraction: 0.75),
            value: viewModel.state
        )
        .ignoresSafeArea()
    }

    // MARK: - Content

    @ViewBuilder
    private var contentLayer: some View {
        switch viewModel.state {
        case .collapsed:
            ZStack {
                // Invisible solid hit target filling the entire panel frame
                Color.black.opacity(0.001)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())

                HStack(spacing: 0) {
                    if TerminalManager.shared.hasRunningServers {
                        collapsedServerStatusDot
                            .transition(.opacity)
                    }

                    Spacer()

                    if let media = mediaManager.currentMedia, media.isPlaying {
                        collapsedMediaAccessory(media)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.requestExpand()
            }
            .onHover { isHovering in
                guard isHovering else { return }
                if configManager.config.general.hoverToExpand {
                    viewModel.requestExpand()
                } else if configManager.config.general.hoverToPeek {
                    viewModel.requestPeek()
                }
            }

        case .peek:
            PeekView(viewModel: viewModel, mediaManager: mediaManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.requestExpand()
                }
                .onHover { isHovering in
                    guard isHovering else { return }
                    if configManager.config.general.hoverToExpand {
                        viewModel.requestExpand()
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.state)

        case .expanded:
            ExpandedView(
                viewModel: viewModel,
                configManager: configManager,
                notesManager: notesManager,
                shelfManager: shelfManager,
                mediaManager: mediaManager,
                calendarManager: calendarManager,
                widgetRegistry: widgetRegistry
            )
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.state)
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
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 9))
                    .foregroundStyle(.purple)
            }

            AudioWaveView(isPlaying: true, color: .purple)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.8))
        .cornerRadius(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 6)
        .padding(.bottom, 2)
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
        var handled = false
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    shelfManager.addItem(
                        from: url,
                        copyOnDrop: configManager.config.general.copyOnDrop
                    )
                }
            }
            handled = true
        }
        return handled
    }
}
