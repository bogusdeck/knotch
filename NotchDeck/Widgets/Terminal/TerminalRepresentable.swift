// TerminalRepresentable.swift
// SwiftUI wrapper for SwiftTerm's LocalProcessTerminalView.
// Uses a persistent container NSView to seamlessly mount and switch active terminal sessions.

import AppKit
import SwiftUI
import SwiftTerm

final class TerminalContainerView: NSView {
    private(set) var currentTerminalView: LocalProcessTerminalView?

    override var isFlipped: Bool { true }

    func setTerminalView(_ newView: LocalProcessTerminalView) {
        if currentTerminalView !== newView || newView.superview !== self {
            currentTerminalView?.removeFromSuperview()
            currentTerminalView = newView

            newView.translatesAutoresizingMaskIntoConstraints = true
            newView.autoresizingMask = [.width, .height]
            addSubview(newView)
        }

        updateTerminalLayout()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateTerminalLayout()
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        updateTerminalLayout()
    }

    override func layout() {
        super.layout()
        updateTerminalLayout()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            updateTerminalLayout()
            focusTerminal()
        }
    }

    private func updateTerminalLayout() {
        guard let terminal = currentTerminalView else { return }
        // Keep frame intact if bounds collapse below threshold (prevents SIGWINCH buffer crushing during notch spring animation)
        if bounds.width >= 160 && bounds.height >= 60 {
            if terminal.frame != bounds {
                terminal.frame = bounds
                terminal.needsDisplay = true
            }
        }
    }

    func focusTerminal() {
        guard let terminal = currentTerminalView, let window = self.window else { return }
        DispatchQueue.main.async { [weak terminal, weak window] in
            guard let terminal = terminal, let window = window else { return }
            window.makeFirstResponder(terminal)
            terminal.needsDisplay = true
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
