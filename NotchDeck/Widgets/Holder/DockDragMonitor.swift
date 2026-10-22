// DockDragMonitor.swift
// Monitors mouse drags starting from the macOS Dock and dragging up to the notch.
// Resolves the dragged Dock item using Accessibility APIs (zero permissions required)
// and coordinates with NotchPanelController to open Holder and receive the app.

import AppKit
import ApplicationServices
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.notchdeck.app", category: "DockDragMonitor")

@MainActor
final class DockDragMonitor {

    static let shared = DockDragMonitor()

    private var globalDragMonitor: Any?
    private var globalUpMonitor: Any?
    private var globalDownMonitor: Any?

    private var dragStartCandidate: (title: String, url: URL?)?
    private var isDraggingTowardNotch: Bool = false

    var onDragApproachingNotch: ((URL?, String) -> Void)?
    var onDragDroppedOnNotch: ((URL?) -> Void)?
    var onDragCancelled: (() -> Void)?

    func start() {
        stop()

        // 1. Monitor left mouse down to catch when a user clicks on an item in the Dock
        globalDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleMouseDown(at: NSEvent.mouseLocation)
            }
        }

        // 2. Monitor left mouse dragged across the system
        globalDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleMouseDragged(at: NSEvent.mouseLocation)
            }
        }

        // 3. Monitor left mouse up to handle drop
        globalUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleMouseUp(at: NSEvent.mouseLocation)
            }
        }

        logger.info("DockDragMonitor started")
    }

    func stop() {
        if let m = globalDownMonitor { NSEvent.removeMonitor(m); globalDownMonitor = nil }
        if let m = globalDragMonitor { NSEvent.removeMonitor(m); globalDragMonitor = nil }
        if let m = globalUpMonitor   { NSEvent.removeMonitor(m); globalUpMonitor   = nil }
        dragStartCandidate = nil
        isDraggingTowardNotch = false
    }

    // MARK: - Event Handling

    private func handleMouseDown(at loc: NSPoint) {
        // In macOS screen coordinates: (0,0) is bottom-left.
        // Dock is typically within the bottom 110pt of the primary screen.
        let bottomThreshold: CGFloat = 110

        if loc.y <= bottomThreshold {
            if let dockApp = findDockApp(atX: loc.x) {
                logger.info("Dock drag candidate detected: \(dockApp.title) at x=\(loc.x)")
                self.dragStartCandidate = dockApp
                return
            }
        }
        self.dragStartCandidate = nil
        self.isDraggingTowardNotch = false
    }

    private func handleMouseDragged(at loc: NSPoint) {
        // If drag didn't register on mousedown but current mouse is still low (< 110)
        if dragStartCandidate == nil && loc.y <= 110 {
            if let dockApp = findDockApp(atX: loc.x) {
                self.dragStartCandidate = dockApp
            }
        }

        guard let candidate = dragStartCandidate else { return }

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let notchFrame = NotchGeometryDetector.detect().notchFrame

        // Trigger area: approaching top 70pt of screen within the horizontal span of the notch (+ margin)
        let triggerY = screen.frame.maxY - 70
        let triggerMinX = notchFrame.midX - (notchFrame.width / 2 + 70)
        let triggerMaxX = notchFrame.midX + (notchFrame.width / 2 + 70)

        if loc.y >= triggerY && loc.x >= triggerMinX && loc.x <= triggerMaxX {
            if !isDraggingTowardNotch {
                isDraggingTowardNotch = true
                logger.info("Dock item \(candidate.title) approached notch! Expanding holder...")
                onDragApproachingNotch?(candidate.url, candidate.title)
            }
        }
    }

    private func handleMouseUp(at loc: NSPoint) {
        guard isDraggingTowardNotch, let candidate = dragStartCandidate else {
            dragStartCandidate = nil
            isDraggingTowardNotch = false
            return
        }

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let notchFrame = NotchGeometryDetector.detect().notchFrame

        // Check if released over expanded notch panel area (expanded panel is typically top 350pt)
        let dropMinY = screen.frame.maxY - 400
        let dropMinX = notchFrame.midX - 350
        let dropMaxX = notchFrame.midX + 350

        if loc.y >= dropMinY && loc.x >= dropMinX && loc.x <= dropMaxX {
            logger.info("Dock item \(candidate.title) dropped on notch! URL: \(candidate.url?.path ?? "nil")")
            onDragDroppedOnNotch?(candidate.url)
        } else {
            logger.info("Dock item drag released outside notch")
            onDragCancelled?()
        }

        dragStartCandidate = nil
        isDraggingTowardNotch = false
    }

    // MARK: - Dock AX Resolution

    func findDockApp(atX x: CGFloat) -> (title: String, url: URL?)? {
        let dockApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock")
        guard let dockApp = dockApps.first else { return nil }
        let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)
        var listRef: AnyObject?
        let err = AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &listRef)
        guard err == .success, let children = listRef as? [AXUIElement], let list = children.first else { return nil }
        var subchildren: AnyObject?
        guard AXUIElementCopyAttributeValue(list, kAXChildrenAttribute as CFString, &subchildren) == .success,
              let items = subchildren as? [AXUIElement] else { return nil }

        for item in items {
            var posVal: AnyObject?
            var sizeVal: AnyObject?
            guard AXUIElementCopyAttributeValue(item, kAXPositionAttribute as CFString, &posVal) == .success,
                  AXUIElementCopyAttributeValue(item, kAXSizeAttribute as CFString, &sizeVal) == .success else { continue }

            var pt = CGPoint.zero
            var sz = CGSize.zero
            if let posVal = posVal as! AXValue?, AXValueGetValue(posVal, .cgPoint, &pt),
               let sizeVal = sizeVal as! AXValue?, AXValueGetValue(sizeVal, .cgSize, &sz) {
                if x >= pt.x && x <= (pt.x + sz.width) {
                    var titleVal: AnyObject?
                    AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleVal)
                    let title = (titleVal as? String) ?? ""
                    let url = resolveAppURL(named: title)
                    return (title, url)
                }
            }
        }
        return nil
    }

    private func resolveAppURL(named title: String) -> URL? {
        guard !title.isEmpty else { return nil }

        // 1. Running app bundle URL
        if let running = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName?.lowercased() == title.lowercased()
        }), let url = running.bundleURL {
            return url
        }

        // 2. Direct Applications path
        let paths = [
            "/Applications/\(title).app",
            "/System/Applications/\(title).app",
            "/System/Applications/Utilities/\(title).app",
            "/System/Library/CoreServices/\(title).app",
            NSHomeDirectory() + "/Applications/\(title).app"
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        // 3. Fallback NSWorkspace application search
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.\(title)") {
            return appURL
        }

        return nil
    }
}
