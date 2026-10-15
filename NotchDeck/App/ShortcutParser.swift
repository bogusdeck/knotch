// ShortcutParser.swift
// Parses string shortcut representations (e.g., "cmd+shift+space") into KeyboardShortcuts.Shortcut.

import AppKit
import Foundation
import KeyboardShortcuts

enum ShortcutParser {

    /// Parses a string like "cmd+shift+space" or "cmd+shift+n" into a KeyboardShortcuts.Shortcut.
    static func parse(_ string: String) -> KeyboardShortcuts.Shortcut? {
        let parts = string.lowercased()
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        guard !parts.isEmpty else { return nil }

        var modifiers: NSEvent.ModifierFlags = []
        var resolvedKey: KeyboardShortcuts.Key?

        for part in parts {
            switch part {
            case "cmd", "command":
                modifiers.insert(.command)
            case "shift":
                modifiers.insert(.shift)
            case "opt", "option", "alt":
                modifiers.insert(.option)
            case "ctrl", "control":
                modifiers.insert(.control)
            default:
                if let key = parseKey(part) {
                    resolvedKey = key
                }
            }
        }

        guard let key = resolvedKey else { return nil }
        return KeyboardShortcuts.Shortcut(key, modifiers: modifiers)
    }

    private static func parseKey(_ token: String) -> KeyboardShortcuts.Key? {
        switch token {
        case "a": return .a
        case "b": return .b
        case "c": return .c
        case "d": return .d
        case "e": return .e
        case "f": return .f
        case "g": return .g
        case "h": return .h
        case "i": return .i
        case "j": return .j
        case "k": return .k
        case "l": return .l
        case "m": return .m
        case "n": return .n
        case "o": return .o
        case "p": return .p
        case "q": return .q
        case "r": return .r
        case "s": return .s
        case "t": return .t
        case "u": return .u
        case "v": return .v
        case "w": return .w
        case "x": return .x
        case "y": return .y
        case "z": return .z

        case "0", "zero": return .zero
        case "1", "one": return .one
        case "2", "two": return .two
        case "3", "three": return .three
        case "4", "four": return .four
        case "5", "five": return .five
        case "6", "six": return .six
        case "7", "seven": return .seven
        case "8", "eight": return .eight
        case "9", "nine": return .nine

        case "space": return .space
        case "return", "enter": return .return
        case "tab": return .tab
        case "escape", "esc": return .escape
        case "comma": return .comma
        case "period": return .period
        case "slash": return .slash
        case "backslash": return .backslash
        case "minus": return .minus
        case "equal": return .equal
        case "semicolon": return .semicolon
        case "quote": return .quote

        case "f1": return .f1
        case "f2": return .f2
        case "f3": return .f3
        case "f4": return .f4
        case "f5": return .f5
        case "f6": return .f6
        case "f7": return .f7
        case "f8": return .f8
        case "f9": return .f9
        case "f10": return .f10
        case "f11": return .f11
        case "f12": return .f12

        default:
            return nil
        }
    }
}
