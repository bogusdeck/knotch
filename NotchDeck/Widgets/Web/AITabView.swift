// AITabView.swift
// Unified AI Assistant tab for NotchDeck with instant switching between ChatGPT and Claude.
// Preserves active sessions, chat state, and scroll position across both providers.

import SwiftUI

enum AIProvider: String, CaseIterable, Identifiable {
    case gpt = "chatgpt"
    case claude = "claude"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gpt: return "ChatGPT"
        case .claude: return "Claude"
        }
    }

    var icon: String {
        switch self {
        case .gpt: return "sparkles"
        case .claude: return "brain.head.profile"
        }
    }

    var brandColor: Color {
        switch self {
        case .gpt: return Color(red: 0.06, green: 0.65, blue: 0.52)
        case .claude: return Color(red: 0.85, green: 0.44, blue: 0.28)
        }
    }

    var defaultURL: URL {
        switch self {
        case .gpt: return URL(string: "https://chatgpt.com")!
        case .claude: return URL(string: "https://claude.ai")!
        }
    }
}

struct AITabView: View {
    @ObservedObject var viewModel: NotchViewModel
    @AppStorage("NotchDeckSelectedAIProvider") private var selectedProviderRaw: String = AIProvider.gpt.rawValue
    @Environment(\.deckTheme) private var theme: DeckTheme

    private var selectedProvider: AIProvider {
        AIProvider(rawValue: selectedProviderRaw) ?? .gpt
    }

    private var aiPickerHeader: some View {
        HStack(spacing: 8) {
            // Segmented Switcher Pill
            HStack(spacing: 2) {
                ForEach(AIProvider.allCases) { provider in
                    let isSelected = selectedProvider == provider
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            selectedProviderRaw = provider.rawValue
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: provider.icon)
                                .font(.system(size: 10.5, weight: .semibold))
                            Text(provider.title)
                                .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                        }
                        .foregroundStyle(isSelected ? provider.brandColor : theme.secondaryText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? provider.brandColor.opacity(0.18) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? provider.brandColor.opacity(0.45) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
            }
            .padding(2.5)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(theme.inputBackground.opacity(0.65))
            )

            // Current Host Badge
            Text(selectedProvider == .gpt ? "chatgpt.com" : "claude.ai")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(theme.tertiaryText)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(theme.inputBackground.opacity(0.6)))
        }
    }

    var body: some View {
        ZStack {
            DedicatedWebView(
                id: "gpt",
                title: "ChatGPT",
                icon: "sparkles",
                brandColor: Color(red: 0.06, green: 0.65, blue: 0.52),
                defaultURL: URL(string: "https://chatgpt.com")!,
                userAgent: WebTabItem.chromeUserAgent,
                viewModel: viewModel,
                customHeaderLeading: AnyView(aiPickerHeader)
            )
            .opacity(selectedProvider == .gpt ? 1 : 0)
            .allowsHitTesting(selectedProvider == .gpt)

            DedicatedWebView(
                id: "claude",
                title: "Claude",
                icon: "brain.head.profile",
                brandColor: Color(red: 0.85, green: 0.44, blue: 0.28),
                defaultURL: URL(string: "https://claude.ai")!,
                userAgent: WebTabItem.chromeUserAgent,
                viewModel: viewModel,
                customHeaderLeading: AnyView(aiPickerHeader)
            )
            .opacity(selectedProvider == .claude ? 1 : 0)
            .allowsHitTesting(selectedProvider == .claude)
        }
    }
}
