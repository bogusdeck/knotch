// NotchGeometry.swift
// Detects the notch position and dimensions from NSScreen APIs.
// Falls back to a floating pill layout on Macs without a notch.

import AppKit
import OSLog

private let logger = Logger(subsystem: "com.notchdeck.app", category: "NotchGeometry")

/// Describes the physical notch (or simulated pill) on a given screen.
struct NotchGeometry: Sendable {
    /// Whether the screen has an actual hardware notch.
    let hasNotch: Bool
    /// Frame of the notch area in screen coordinates (origin at bottom-left of screen).
    let notchFrame: CGRect
    /// Insets the screen's safe area reserves for the notch.
    let safeAreaInsets: NSEdgeInsets
    /// The screen this geometry was derived from.
    let screenFrame: CGRect
}

@MainActor
enum NotchGeometryDetector {

    // MARK: - Public API

    /// Returns geometry for the preferred screen (built-in first, then main).
    static func detect() -> NotchGeometry {
        let screen = preferredScreen()
        return geometry(for: screen)
    }

    /// Returns geometry for a specific screen.
    static func geometry(for screen: NSScreen) -> NotchGeometry {
        let insets = screen.safeAreaInsets
        let screenFrame = screen.frame

        // The notch is present when the top safe-area inset is non-zero.
        let hasNotch = insets.top > 0

        let notchFrame: CGRect
        if hasNotch {
            // Derive notch frame from auxiliaryTopLeftArea / auxiliaryTopRightArea.
            // The notch sits between these two rects.
            let leftAux  = screen.auxiliaryTopLeftArea  ?? .zero
            let rightAux = screen.auxiliaryTopRightArea ?? .zero

            let notchLeft   = leftAux.maxX
            let notchRight  = rightAux.minX
            let notchWidth  = max(0, notchRight - notchLeft)
            let notchTop    = screenFrame.maxY           // top of screen
            let notchHeight = insets.top

            notchFrame = CGRect(
                x: screenFrame.minX + notchLeft,
                y: notchTop - notchHeight,
                width: notchWidth,
                height: notchHeight
            )
            logger.debug("Notch detected: \(notchFrame.debugDescription)")
        } else {
            // No notch — place a floating pill at the top-center of the screen.
            let pillWidth: CGFloat  = 200
            let pillHeight: CGFloat = 30
            notchFrame = CGRect(
                x: screenFrame.midX - pillWidth / 2,
                y: screenFrame.maxY - pillHeight - 4,
                width: pillWidth,
                height: pillHeight
            )
            logger.debug("No notch — pill at: \(notchFrame.debugDescription)")
        }

        return NotchGeometry(
            hasNotch: hasNotch,
            notchFrame: notchFrame,
            safeAreaInsets: insets,
            screenFrame: screenFrame
        )
    }

    // MARK: - Helpers

    /// Returns the built-in display, or falls back to the main screen.
    static func preferredScreen() -> NSScreen {
        // Built-in displays have `localizedName` containing "Built-in" or are
        // identified via `NSScreen.screens` — the built-in is always first on
        // MacBooks when no external display forces a reorder.
        let builtIn = NSScreen.screens.first {
            $0.localizedName.lowercased().contains("built-in") ||
            $0.localizedName.lowercased().contains("liquid retina") ||
            $0.localizedName.lowercased().contains("retina")
        }
        return builtIn ?? NSScreen.main ?? NSScreen.screens[0]
    }
}
