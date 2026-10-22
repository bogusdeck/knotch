// AppDelegate.swift
// Bootstraps the entire NotchDeck application.
// Owns the NotchPanelController and status-bar item (fallback for non-notch Macs).

import AppKit
import AuthenticationServices
import Combine
import KeyboardShortcuts
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.notchdeck.app", category: "AppDelegate")

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var panelController: NotchPanelController?
    private var statusItem: NSStatusItem?
    private var configManager: ConfigManager?
    private var settingsWindowController: NSWindowController?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("NotchDeck starting up")

        // 1. Boot config system (creates ~/.config/notchdeck/ if needed)
        let configManager = ConfigManager()
        self.configManager = configManager

        // 2. Create the notch panel
        let panelController = NotchPanelController(configManager: configManager)
        self.panelController = panelController
        panelController.show()

        // 3. Register global shortcuts and observe updates
        registerShortcuts()
        observeShortcuts()

        // 4. Status-bar item as fallback icon / right-click menu
        setupStatusItem()

        // 5. Never appear in the Dock or app switcher
        NSApp.setActivationPolicy(.accessory)

        // 6. Memory optimization: cap URLCache memory footprint to 20MB (default is 512MB)
        URLCache.shared = URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024)

        // 7. Request WebBrowser public key credentials (Passkeys / Touch ID) authorization
        if #available(macOS 13.3, *) {
            let credManager = ASAuthorizationWebBrowserPublicKeyCredentialManager()
            if credManager.authorizationStateForPlatformCredentials == .notDetermined {
                credManager.requestAuthorizationForPublicKeyCredentials { state in
                    logger.info("Passkey authorization state: \(state.rawValue)")
                }
            }
        }

        logger.info("NotchDeck ready")
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("NotchDeck terminating")
    }

    // MARK: - Shortcuts

    private func registerShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .toggleNotch) { [weak self] in
            self?.panelController?.toggleExpanded()
        }
        KeyboardShortcuts.onKeyUp(for: .quickNote) { [weak self] in
            self?.panelController?.openQuickNote()
        }
    }

    private func observeShortcuts() {
        configManager?.$config
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newConfig in
                self?.applyShortcuts(from: newConfig)
                self?.setupStatusItem()
            }
            .store(in: &cancellables)
    }

    private func applyShortcuts(from config: AppConfig) {
        if let toggleShortcut = ShortcutParser.parse(config.shortcuts.toggle) {
            KeyboardShortcuts.setShortcut(toggleShortcut, for: .toggleNotch)
        }
        if let quickNoteShortcut = ShortcutParser.parse(config.shortcuts.quickNote) {
            KeyboardShortcuts.setShortcut(quickNoteShortcut, for: .quickNote)
        }

        // Per-widget shortcuts:
        for widget in config.widgets {
            guard let shortcutStr = widget.shortcut,
                  let shortcut = ShortcutParser.parse(shortcutStr) else { continue }
            let name = KeyboardShortcuts.Name("widget_\(widget.id)")
            KeyboardShortcuts.setShortcut(shortcut, for: name)
            KeyboardShortcuts.onKeyUp(for: name) { [weak self] in
                self?.panelController?.selectWidgetTab(id: widget.id)
            }
        }
    }

    // MARK: - Status item

    private func setupStatusItem() {
        let shouldShow = configManager?.config.general.showMenuBarIcon ?? false
        if shouldShow {
            if statusItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                if let button = item.button {
                    button.image = NSImage(
                        systemSymbolName: "rectangle.topthird.inset.filled",
                        accessibilityDescription: "NotchDeck"
                    )
                    button.action = #selector(statusItemClicked)
                    button.target = self
                }
                item.menu = buildStatusMenu()
                self.statusItem = item
            }
        } else {
            if let existing = statusItem {
                NSStatusBar.system.removeStatusItem(existing)
                self.statusItem = nil
            }
        }
    }

    @objc private func statusItemClicked() {
        panelController?.toggleExpanded()
    }

    private func buildStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Toggle NotchDeck", action: #selector(statusItemClicked), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit NotchDeck", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    @objc private func checkForUpdates() {
        UpdaterManager.shared.checkForUpdates()
    }

    @objc func openSettings() {
        if let panelController {
            panelController.openSettings()
            return
        }

        guard let configManager else { return }
        let settingsView = SettingsView(configManager: configManager)
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "NotchDeck Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 600, height: 460))
        window.center()
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        self.settingsWindowController = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
