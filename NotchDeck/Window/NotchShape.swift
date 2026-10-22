// NotchShape.swift
// A custom Shape that draws the notch background for each state.
// In collapsed state on a notch Mac, it renders a rectangle with notch-specific
// concave corners to blend seamlessly into the bezel.
// In peek/expanded states it draws a rounded-rectangle growing downward.

import SwiftUI

struct NotchShape: Shape {

    let hasNotch: Bool
    var state: NotchState

    /// Animatable data — drives the morphing animation.
    var animatableData: Double {
        get { stateValue }
        set { stateValue = newValue }
    }

    private var stateValue: Double
    private var customExpandedRadius: CGFloat

    init(hasNotch: Bool, state: NotchState, cornerRadius: CGFloat = 22) {
        self.hasNotch             = hasNotch
        self.state                = state
        self.stateValue           = state.animatableValue
        self.customExpandedRadius = cornerRadius
    }

    func path(in rect: CGRect) -> Path {
        // Interpolate corner radius based on state value
        let radius = lerp(from: collapsedRadius, to: customExpandedRadius, t: stateValue)
        let concaveR: CGFloat = hasNotch ? 8 : 0   // concave side corners on notch Macs

        switch hasNotch {
        case true:
            return notchPath(in: rect, cornerRadius: radius, concaveRadius: concaveR)
        case false:
            return pillPath(in: rect, cornerRadius: radius)
        }
    }

    // MARK: - Radii

    private var collapsedRadius: CGFloat { hasNotch ? 12 : 12 }
    private var expandedRadius:  CGFloat { customExpandedRadius }

    // MARK: - Path builders

    /// Draws a shape with:
    ///   - straight/slightly-rounded top (to blend with the bezel)
    ///   - concave outer top corners (matches hardware notch)
    ///   - rounded bottom corners
    private func notchPath(in rect: CGRect, cornerRadius r: CGFloat, concaveRadius cr: CGFloat) -> Path {
        var path = Path()

        let minX = rect.minX, maxX = rect.maxX
        let minY = rect.minY, maxY = rect.maxY

        // Top-left concave corner
        path.move(to: CGPoint(x: minX, y: minY))
        path.addLine(to: CGPoint(x: minX, y: minY + cr))
        path.addQuadCurve(
            to:       CGPoint(x: minX + cr, y: minY),
            control:  CGPoint(x: minX,      y: minY)
        )

        // Top edge
        path.addLine(to: CGPoint(x: maxX - cr, y: minY))

        // Top-right concave corner
        path.addQuadCurve(
            to:       CGPoint(x: maxX, y: minY + cr),
            control:  CGPoint(x: maxX, y: minY)
        )

        // Right edge → bottom-right rounded corner
        path.addLine(to: CGPoint(x: maxX, y: maxY - r))
        path.addQuadCurve(
            to:      CGPoint(x: maxX - r, y: maxY),
            control: CGPoint(x: maxX,     y: maxY)
        )

        // Bottom edge → bottom-left rounded corner
        path.addLine(to: CGPoint(x: minX + r, y: maxY))
        path.addQuadCurve(
            to:      CGPoint(x: minX, y: maxY - r),
            control: CGPoint(x: minX, y: maxY)
        )

        path.closeSubpath()
        return path
    }

    /// Simple rounded rectangle for non-notch Macs.
    private func pillPath(in rect: CGRect, cornerRadius r: CGFloat) -> Path {
        Path(roundedRect: rect, cornerRadius: r)
    }

    // MARK: - Helpers

    private func lerp(from a: CGFloat, to b: CGFloat, t: Double) -> CGFloat {
        a + (b - a) * CGFloat(t)
    }
}

// MARK: - State → animatable value mapping

extension NotchState {
    var animatableValue: Double {
        switch self {
        case .collapsed: 0.0
        case .peek:      0.5
        case .expanded:  1.0
        }
    }
}
