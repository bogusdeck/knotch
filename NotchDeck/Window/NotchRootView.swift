// NotchRootView.swift
// The top-level SwiftUI view mounted inside the NSPanel.
// Renders the correct sub-view for each state (collapsed / peek / expanded)
// and orchestrates spring animations between them.

import SwiftUI

struct NotchRootView: View {

    @ObservedObject var viewModel: NotchViewModel

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
            ExpandedView(viewModel: viewModel)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.state)
        }
    }
}
