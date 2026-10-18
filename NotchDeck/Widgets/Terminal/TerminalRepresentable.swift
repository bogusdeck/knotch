// TerminalRepresentable.swift
// SwiftUI wrapper for SwiftTerm's LocalProcessTerminalView.
// Uses a persistent container NSView to seamlessly mount and switch active terminal sessions.

import AppKit
import SwiftUI
import SwiftTerm

final class TerminalContainerView: NSView {
    private(set) var currentTerminalView: LocalProcessTerminalView?

    func setTerminalView(_ newView: LocalProcessTerminalView) {
        if currentTerminalView !== newView || newView.superview !== self {
            currentTerminalView?.removeFromSuperview()
            currentTerminalView = newView

            newView.wantsLayer = true
            newView.layer?.backgroundColor = NSColor.clear.cgColor
            addSubview(newView)
        }

        // Only resize terminal when bounds are realistic (prevents SIGWINCH corruption during collapse)
        if bounds.width >= 160 && bounds.height >= 60 {
            newView.frame = bounds
        }

        newView.needsDisplay = true
        newView.needsLayout = true

        DispatchQueue.main.async { [weak self, weak newView] in
            guard let self = self, let newView = newView else { return }
            if self.bounds.width >= 160 && self.bounds.height >= 60 {
                newView.frame = self.bounds
            }
            self.window?.makeFirstResponder(newView)
            newView.needsDisplay = true
        }
    }

    override func layout() {
        super.layout()
        // Never crush terminal columns/rows during notch collapse animation
        if bounds.width >= 160 && bounds.height >= 60 {
            currentTerminalView?.frame = bounds
            currentTerminalView?.needsDisplay = true
        }
    }
}

struct TerminalRepresentable: NSViewRepresentable {
    let terminalView: LocalProcessTerminalView

    func makeNSView(context: Context) -> TerminalContainerView {
        let container = TerminalContainerView()
        container.setTerminalView(terminalView)
        return container
    }

    func updateNSView(_ container: TerminalContainerView, context: Context) {
        container.setTerminalView(terminalView)
    }
}
