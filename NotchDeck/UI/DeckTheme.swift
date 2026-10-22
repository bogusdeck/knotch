// DeckTheme.swift
// Adaptive theme engine supporting Dark (HUD), Light (Apple frosted glass), and System auto-detection.

import AppKit
import SwiftUI

struct DeckTheme: Sendable {
    let isLight: Bool
    let accent: Color

    static func current(theme: String, accentHex: String) -> DeckTheme {
        let isLight: Bool
        let t = theme.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if t == "light" {
            isLight = true
        } else if t == "dark" {
            isLight = false
        } else {
            // Auto / System appearance
            let appearance = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
            isLight = (appearance == .aqua)
        }

        let accentColor = Color(hex: accentHex) ?? Color(red: 0.49, green: 0.36, blue: 1.0)
        return DeckTheme(isLight: isLight, accent: accentColor)
    }

    // Window & Background
    var background: Color {
        isLight ? Color(nsColor: .windowBackgroundColor) : Color.black
    }

    var outerBorder: Color {
        isLight ? Color.black.opacity(0.12) : Color.clear
    }

    // Text hierarchy
    var primaryText: Color {
        isLight ? Color(white: 0.12) : .white
    }

    var secondaryText: Color {
        isLight ? Color(white: 0.45) : .white.opacity(0.65)
    }

    var tertiaryText: Color {
        isLight ? Color(white: 0.60) : .white.opacity(0.40)
    }

    // Cards and Tiles
    var cardBackground: Color {
        isLight ? Color.white.opacity(0.82) : Color.white.opacity(0.05)
    }

    var cardBorder: Color {
        isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.08)
    }

    var divider: Color {
        isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.08)
    }

    var barTrack: Color {
        isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.08)
    }

    // Tabs & Controls
    var tabSelected: Color {
        isLight ? Color.black.opacity(0.12) : Color.white.opacity(0.18)
    }

    var tabHover: Color {
        isLight ? Color.black.opacity(0.06) : Color.white.opacity(0.08)
    }

    var inputBackground: Color {
        isLight ? Color.black.opacity(0.05) : Color.white.opacity(0.08)
    }

    var cutoutBlend: Color {
        isLight ? Color.black.opacity(0.15) : Color.white.opacity(0.06)
    }
}

private struct DeckThemeKey: EnvironmentKey {
    static let defaultValue = DeckTheme(isLight: false, accent: Color(red: 0.49, green: 0.36, blue: 1.0))
}

extension EnvironmentValues {
    var deckTheme: DeckTheme {
        get { self[DeckThemeKey.self] }
        set { self[DeckThemeKey.self] = newValue }
    }
}

extension Color {
    init?(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHex.hasPrefix("#") {
            cleanHex.removeFirst()
        }
        guard cleanHex.count == 6, let rgbValue = UInt64(cleanHex, radix: 16) else {
            return nil
        }
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}

// MARK: - Global Cursor State

@MainActor
final class DeckCursorState {
    static var activePointingHandCount: Int = 0
    static var isPointingHandActive: Bool {
        activePointingHandCount > 0
    }
}

// MARK: - Pointing Hand Cursor Modifier

private struct PointingHandCursorModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                guard isHovering != hovering else { return }
                isHovering = hovering
                if hovering {
                    DeckCursorState.activePointingHandCount += 1
                    NSCursor.pointingHand.set()
                } else {
                    DeckCursorState.activePointingHandCount = max(0, DeckCursorState.activePointingHandCount - 1)
                    if !DeckCursorState.isPointingHandActive {
                        NSCursor.arrow.set()
                    }
                }
            }
            .onDisappear {
                if isHovering {
                    isHovering = false
                    DeckCursorState.activePointingHandCount = max(0, DeckCursorState.activePointingHandCount - 1)
                    if !DeckCursorState.isPointingHandActive {
                        NSCursor.arrow.set()
                    }
                }
            }
    }
}

extension View {
    /// Changes the cursor to pointingHand when hovering over interactive elements
    func pointingHandCursor() -> some View {
        modifier(PointingHandCursorModifier())
    }
}
