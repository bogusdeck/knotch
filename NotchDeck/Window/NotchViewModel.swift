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
    @Published var activeCustomTabId: String? = nil

    /// In-notch settings mode state
    @Published var isSettingsActive: Bool = false
    @Published var selectedSettingsCategory: SettingsCategory = .general

    /// Non-nil when config.toml has a parse or I/O error
    @Published var configError: ConfigError? = nil

    /// Set to true by the controller when Quick Note shortcut fires.
    @Published var requestFocusOnNoteInput: Bool = false

    /// Drives spring animation phase; toggled when state changes.
    @Published var animationPhase: Bool = false

    /// Geometry is updated on screen-change notifications.
    @Published var geometry: NotchGeometry

    /// Whether the terminal panel is expanded to enlarged full-size dimensions
    @Published var isTerminalZoomed: Bool = false

    /// Callbacks invoked when a view needs to trigger panel window expansion/collapse/peek
    var onExpandRequested: (@MainActor () -> Void)?
    var onCollapseRequested: (@MainActor () -> Void)?
    var onPeekRequested: (@MainActor () -> Void)?
    var onTerminalZoomToggled: (@MainActor () -> Void)?

    func requestExpand() {
        onExpandRequested?()
    }

    func requestCollapse() {
        onCollapseRequested?()
    }

    func requestPeek() {
        onPeekRequested?()
    }

    func toggleTerminalZoom() {
        isTerminalZoomed.toggle()
        onTerminalZoomToggled?()
    }

    func openSettingsInsideNotch(category: SettingsCategory = .general) {
        selectedSettingsCategory = category
        isSettingsActive = true
        if state != .expanded {
            requestExpand()
        }
    }

    func closeSettingsInsideNotch() {
        isSettingsActive = false
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
