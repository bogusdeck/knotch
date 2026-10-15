// WebWidgetBridge.swift
// Implements the window.notch JavaScript bridge for user web widgets.

import AppKit
import Foundation
import OSLog
import UserNotifications
import WebKit

private let logger = Logger(subsystem: "com.notchdeck.app", category: "WebWidgetBridge")

@MainActor
final class WebWidgetBridge: NSObject, WKScriptMessageHandlerWithReply {

    let widgetId: String
    let widgetTitle: String
    let allowShell: Bool
    let widgetDirURL: URL
    let configJSON: String

    private var storage: [String: Any] = [:]
    private var storageFileURL: URL {
        widgetDirURL.appendingPathComponent("storage.json")
    }

    init(
        widgetId: String,
        widgetTitle: String,
        allowShell: Bool,
        widgetDirURL: URL,
        widgetConfig: [String: Any]
    ) {
        self.widgetId = widgetId
        self.widgetTitle = widgetTitle
        self.allowShell = allowShell
        self.widgetDirURL = widgetDirURL

        // Serialize widgetConfig to JSON string for JS injection
        if let data = try? JSONSerialization.data(withJSONObject: widgetConfig, options: []),
           let jsonStr = String(data: data, encoding: .utf8) {
            self.configJSON = jsonStr
        } else {
            self.configJSON = "{}"
        }

        super.init()
        loadStorage()
    }

    private func loadStorage() {
        guard FileManager.default.fileExists(atPath: storageFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageFileURL)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                self.storage = dict
            }
        } catch {
            logger.warning("Failed to load storage for web widget '\(self.widgetId)': \(error.localizedDescription)")
        }
    }

    private func saveStorage() {
        do {
            let data = try JSONSerialization.data(withJSONObject: storage, options: [.prettyPrinted])
            try data.write(to: storageFileURL, options: .atomic)
        } catch {
            logger.error("Failed to save storage for web widget '\(self.widgetId)': \(error.localizedDescription)")
        }
    }

    /// Generates the initialization script to establish window.notch in the page environment
    func injectionScript() -> String {
        """
        (function() {
            window.notch = {
                config: \(configJSON),
                run: function(command) {
                    return window.webkit.messageHandlers.notchBridge.postMessage({
                        action: 'run',
                        command: command
                    });
                },
                storage: {
                    get: function(key) {
                        return window.webkit.messageHandlers.notchBridge.postMessage({
                            action: 'storageGet',
                            key: key
                        });
                    },
                    set: function(key, value) {
                        return window.webkit.messageHandlers.notchBridge.postMessage({
                            action: 'storageSet',
                            key: key,
                            value: value
                        });
                    }
                },
                notify: function(text) {
                    return window.webkit.messageHandlers.notchBridge.postMessage({
                        action: 'notify',
                        text: text
                    });
                }
            };
        })();
        """
    }

    // MARK: - WKScriptMessageHandlerWithReply

    // MARK: - WKScriptMessageHandlerWithReply

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) async -> (Any?, String?) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else {
            return (nil, "Invalid message format")
        }

        switch action {
        case "run":
            guard let command = body["command"] as? String else {
                return (nil, "Missing 'command' argument")
            }

            guard self.allowShell else {
                logger.warning("Web widget '\(self.widgetId)' attempted shell execution but allow_shell is false")
                return (nil, "Permission denied: allow_shell = false for widget '\(self.widgetId)' in config.toml")
            }

            logger.info("Executing shell command for web widget '\(self.widgetId)': \(command)")
            do {
                let result = try await CommandRunner.run(command, timeout: 15)
                if !result.isSuccess {
                    return (nil, result.stderr.isEmpty ? "Command failed with code \(result.exitCode)" : result.stderr)
                } else {
                    return (result.stdout, nil)
                }
            } catch {
                return (nil, error.localizedDescription)
            }

        case "storageGet":
            guard let key = body["key"] as? String else {
                return (nil, "Missing 'key' argument")
            }
            let val = self.storage[key] ?? NSNull()
            return (val, nil)

        case "storageSet":
            guard let key = body["key"] as? String else {
                return (nil, "Missing 'key' argument")
            }
            let val = body["value"]
            self.storage[key] = val
            self.saveStorage()
            return (true, nil)

        case "notify":
            let text = (body["text"] as? String) ?? ""
            let content = UNMutableNotificationContent()
            content.title = self.widgetTitle.isEmpty ? "NotchDeck" : self.widgetTitle
            content.body = text
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "web_widget_\(self.widgetId)_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: nil
            )
            try? await UNUserNotificationCenter.current().add(request)
            return (true, nil)

        default:
            return (nil, "Unknown action: \(action)")
        }
    }
}
