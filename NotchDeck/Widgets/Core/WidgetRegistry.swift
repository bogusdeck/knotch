// WidgetRegistry.swift
// Maintains the ordered list of active widgets derived from config.toml.

import Combine
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.notchdeck.app", category: "WidgetRegistry")

/// Centralised store for all active ``NotchWidget`` instances.
@MainActor
final class WidgetRegistry: ObservableObject {

    // MARK: - Published state

    @Published private(set) var widgets: [AnyNotchWidget] = []

    // Built-in widget IDs that shouldn't be removed during dynamic config sync
    private let builtInIds: Set<String> = ["notes", "shelf", "media", "terminal", "clock", "calendar"]

    // Keep strong references to ObservableObject widgets so their async polling tasks stay alive
    private var actionWidgets: [String: ActionWidget] = [:]
    private var shellWidgets: [String: ShellWidget] = [:]

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
        actionWidgets[id]?.stopPolling()
        actionWidgets.removeValue(forKey: id)
        shellWidgets[id]?.stopPolling()
        shellWidgets.removeValue(forKey: id)

        widgets.removeAll { $0.id == id }
        logger.debug("Unregistered widget: \(id)")
    }

    /// Returns the widget with the given id, if registered.
    func widget(id: String) -> AnyNotchWidget? {
        widgets.first { $0.id == id }
    }

    // MARK: - Dynamic Config Sync

    /// Synchronizes action, shell, and custom widgets defined in config.toml.
    func syncConfiguredWidgets(configs: [WidgetConfig]) {
        let activeConfigIds = Set(configs.map(\.id))

        // Remove stale dynamic widgets
        let toRemove = widgets.filter { !builtInIds.contains($0.id) && !activeConfigIds.contains($0.id) }
        for w in toRemove {
            unregister(id: w.id)
        }

        // Add or update widgets from config
        for cfg in configs {
            switch cfg.type {
            case "action":
                let actionWidget = ActionWidget(config: cfg)
                actionWidgets[cfg.id] = actionWidget
                register(actionWidget)
            case "shell":
                let shellWidget = ShellWidget(config: cfg)
                shellWidgets[cfg.id] = shellWidget
                register(shellWidget)
            case "web":
                var dict: [String: Any] = [
                    "id": cfg.id,
                    "type": cfg.type,
                    "title": cfg.title,
                    "allow_shell": cfg.allowShell
                ]
                if let p = cfg.path { dict["path"] = p }
                let webWidget = WebWidget(
                    id: cfg.id,
                    title: cfg.title,
                    iconName: cfg.icon ?? "globe",
                    relativePath: cfg.path,
                    allowShell: cfg.allowShell,
                    rawConfig: dict
                )
                register(webWidget)
            default:
                break
            }
        }

        logger.info("Synchronized \(self.widgets.count) total widgets in registry")
    }
}
