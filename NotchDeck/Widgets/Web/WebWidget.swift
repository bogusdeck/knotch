// WebWidget.swift
// Conforms user-defined web widgets to the NotchWidget protocol.

import SwiftUI

struct WebWidget: NotchWidget {
    let id: String
    let title: String
    let iconName: String?
    let relativePath: String?
    let allowShell: Bool
    let rawConfig: [String: Any]

    init(
        id: String,
        title: String,
        iconName: String? = "globe",
        relativePath: String?,
        allowShell: Bool = false,
        rawConfig: [String: Any] = [:]
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.relativePath = relativePath
        self.allowShell = allowShell
        self.rawConfig = rawConfig
    }

    func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 6) {
                Image(systemName: iconName ?? "globe")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
        )
    }

    func expandedView() -> AnyView {
        AnyView(
            WebWidgetView(
                widgetId: id,
                title: title,
                relativePath: relativePath,
                allowShell: allowShell,
                widgetConfig: rawConfig
            )
        )
    }
}
