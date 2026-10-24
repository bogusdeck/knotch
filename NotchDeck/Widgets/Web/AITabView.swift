// AITabView.swift
// Unified AI Assistant tab for NotchDeck with instant switching between ChatGPT, Claude, Gemini, and DeepSeek.
// Preserves active sessions, chat state, and scroll position across all providers.

import SwiftUI

enum AIProvider: String, CaseIterable, Identifiable {
    case gpt = "chatgpt"
    case claude = "claude"
    case gemini = "gemini"
    case deepseek = "deepseek"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gpt: return "ChatGPT"
        case .claude: return "Claude"
        case .gemini: return "Gemini"
        case .deepseek: return "DeepSeek"
        }
    }

    var icon: String {
        switch self {
        case .gpt: return "sparkles"
        case .claude: return "brain.head.profile"
        case .gemini: return "sparkle"
        case .deepseek: return "atom"
        }
    }

    var brandColor: Color {
        switch self {
        case .gpt: return Color(red: 0.06, green: 0.65, blue: 0.52)      // OpenAI Teal
        case .claude: return Color(red: 0.85, green: 0.44, blue: 0.28)   // Anthropic Terracotta
        case .gemini: return Color(red: 0.26, green: 0.52, blue: 0.96)   // Google Blue
        case .deepseek: return Color(red: 0.30, green: 0.45, blue: 1.0)   // DeepSeek Blue
        }
    }

    var defaultURL: URL {
        switch self {
        case .gpt: return URL(string: "https://chatgpt.com")!
        case .claude: return URL(string: "https://claude.ai")!
        case .gemini: return URL(string: "https://gemini.google.com")!
        case .deepseek: return URL(string: "https://chat.deepseek.com")!
        }
    }

    var hostName: String {
        switch self {
        case .gpt: return "chatgpt.com"
        case .claude: return "claude.ai"
        case .gemini: return "gemini.google.com"
        case .deepseek: return "chat.deepseek.com"
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
                        HStack(spacing: 4) {
                            Image(systemName: provider.icon)
                                .font(.system(size: 10, weight: .semibold))
                            Text(provider.title)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                        }
                        .foregroundStyle(isSelected ? provider.brandColor : theme.secondaryText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
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
            Text(selectedProvider.hostName)
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

            DedicatedWebView(
                id: "gemini",
                title: "Gemini",
                icon: "sparkle",
                brandColor: Color(red: 0.26, green: 0.52, blue: 0.96),
                defaultURL: URL(string: "https://gemini.google.com")!,
                userAgent: WebTabItem.chromeUserAgent,
                viewModel: viewModel,
                customHeaderLeading: AnyView(aiPickerHeader)
            )
            .opacity(selectedProvider == .gemini ? 1 : 0)
            .allowsHitTesting(selectedProvider == .gemini)

            DedicatedWebView(
                id: "deepseek",
                title: "DeepSeek",
                icon: "atom",
                brandColor: Color(red: 0.30, green: 0.45, blue: 1.0),
                defaultURL: URL(string: "https://chat.deepseek.com")!,
                userAgent: WebTabItem.chromeUserAgent,
                viewModel: viewModel,
                customHeaderLeading: AnyView(aiPickerHeader)
            )
            .opacity(selectedProvider == .deepseek ? 1 : 0)
            .allowsHitTesting(selectedProvider == .deepseek)
        }
    }
}
