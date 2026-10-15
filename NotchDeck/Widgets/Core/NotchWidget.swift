// NotchWidget.swift
// Core protocol every NotchDeck widget must conform to.

import SwiftUI

/// Every NotchDeck widget — built-in or user-created — conforms to this protocol.
///
/// Widgets are registered in `WidgetRegistry` and instantiated from config.toml entries.
/// Phase 1 defines the protocol and registry scaffold; concrete implementations land
/// in Phases 3–5.
@MainActor
protocol NotchWidget: Identifiable {
    /// Unique identifier matching the `id` field in config.toml.
    var id: String { get }
    /// Human-readable title shown in the tab bar.
    var title: String { get }
    /// Small view shown in the peek state (should be ≤ 30 pt tall).
    func compactView() -> AnyView
    /// Full view shown inside the expanded notch dashboard.
    func expandedView() -> AnyView
}

// MARK: - Type-erased widget wrapper

/// Type-erased wrapper so widgets with different concrete types can be stored together.
@MainActor
struct AnyNotchWidget: NotchWidget {
    let id: String
    let title: String

    private let _compactView:  @MainActor () -> AnyView
    private let _expandedView: @MainActor () -> AnyView

    init<W: NotchWidget>(_ widget: W) {
        id             = widget.id
        title          = widget.title
        _compactView   = { widget.compactView() }
        _expandedView  = { widget.expandedView() }
    }

    func compactView()  -> AnyView { _compactView() }
    func expandedView() -> AnyView { _expandedView() }
}
