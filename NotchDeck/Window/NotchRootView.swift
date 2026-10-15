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
            // Nothing visible — the panel frame matches the notch exactly
            EmptyView()

        case .peek:
            PeekView(viewModel: viewModel)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.state)

        case .expanded:
            ExpandedView(
                viewModel: viewModel,
                configManager: configManager,
                notesManager: notesManager,
                shelfManager: shelfManager
            )
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.state)
        }
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
