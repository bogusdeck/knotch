// TerminalRepresentable.swift
// SwiftUI wrapper for SwiftTerm's LocalProcessTerminalView.

import AppKit
import SwiftUI
import SwiftTerm

struct TerminalRepresentable: NSViewRepresentable {
    let terminalView: LocalProcessTerminalView

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        terminalView.wantsLayer = true
        terminalView.layer?.backgroundColor = NSColor.clear.cgColor
        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Maintained by TerminalSession; no state sync needed
    }
}
