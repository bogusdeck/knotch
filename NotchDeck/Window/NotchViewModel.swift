// NotchViewModel.swift
// Observable view model shared between the panel controller and SwiftUI views.
// Drives animations via @Published state.

import Combine
import Foundation
import SwiftUI

/// Which tab is shown in the expanded notch.
enum NotchTab: String, CaseIterable {
    case home, notes, shelf, terminal, vpn
}

@MainActor
final class NotchViewModel: ObservableObject {

    // MARK: - State

    @Published var state: NotchState = .collapsed
    @Published var activeTab: NotchTab = .home

    /// Non-nil when config.toml has a parse or I/O error
    @Published var configError: ConfigError? = nil

    /// Set to true by the controller when Quick Note shortcut fires.
    @Published var requestFocusOnNoteInput: Bool = false

    /// Drives spring animation phase; toggled when state changes.
    @Published var animationPhase: Bool = false

    /// Geometry is updated on screen-change notifications.
    @Published var geometry: NotchGeometry

    /// Callbacks invoked when a view needs to trigger panel window expansion/collapse
    var onExpandRequested: (@MainActor () -> Void)?
    var onCollapseRequested: (@MainActor () -> Void)?

    func requestExpand() {
        onExpandRequested?()
    }

    func requestCollapse() {
        onCollapseRequested?()
    }

    // MARK: - Init

    init(geometry: NotchGeometry) {
        self.geometry = geometry
    }

    // MARK: - Derived geometry for views

    var cornerRadius: CGFloat {
        switch state {
        case .collapsed: return geometry.hasNotch ? 0 : 12
        case .peek:      return 18
        case .expanded:  return 22
        }
    }
}
