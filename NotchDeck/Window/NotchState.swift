// NotchState.swift
// State machine for the notch panel's three display states.

import Foundation

/// The three visual states the notch panel can be in.
enum NotchState: Equatable, Sendable {
    /// Invisible / matches the physical notch shape exactly.
    case collapsed
    /// Slightly expanded on hover, showing quick-glance info.
    case peek
    /// Fully open dashboard.
    case expanded
}

extension NotchState {
    var isVisible: Bool {
        self != .collapsed
    }
}
