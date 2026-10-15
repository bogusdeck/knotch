// WidgetRegistry.swift
// Maintains the ordered list of active widgets derived from config.toml.
// Phase 1: scaffolding only. Phase 2 populates from config.

import Combine
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.notchdeck.app", category: "WidgetRegistry")

/// Centralised store for all active ``NotchWidget`` instances.
@MainActor
final class WidgetRegistry: ObservableObject {

    // MARK: - Published state

    @Published private(set) var widgets: [AnyNotchWidget] = []

    // MARK: - Registration

    /// Registers a widget, replacing any existing widget with the same id.
    func register<W: NotchWidget>(_ widget: W) {
        let wrapped = AnyNotchWidget(widget)
        if let idx = widgets.firstIndex(where: { $0.id == wrapped.id }) {
            widgets[idx] = wrapped
            logger.debug("Updated widget: \(wrapped.id)")
        } else {
            widgets.append(wrapped)
            logger.debug("Registered widget: \(wrapped.id)")
        }
    }

    /// Removes the widget with the given id.
    func unregister(id: String) {
        widgets.removeAll { $0.id == id }
        logger.debug("Unregistered widget: \(id)")
    }

    /// Returns the widget with the given id, if registered.
    func widget(id: String) -> AnyNotchWidget? {
        widgets.first { $0.id == id }
    }
}
