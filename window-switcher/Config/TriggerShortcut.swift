import AppKit
import HotKey
import SwiftUI

struct TriggerShortcut: Equatable {
    let key: Key
    let modifiers: NSEvent.ModifierFlags

    static let `default` = TriggerShortcut(key: .tab, modifiers: [.option])

    var displayString: String {
        keyCombo.description
    }

    var keyCombo: KeyCombo {
        KeyCombo(key: key, modifiers: modifiers)
    }

    var menuShortcut: KeyboardShortcut? {
        guard let keyEquivalent = keyEquivalent else {
            return nil
        }

        return KeyboardShortcut(keyEquivalent, modifiers: eventModifiers)
    }

    func matches(key: KeyEquivalent, characters: String, modifiers: EventModifiers) -> Bool {
        guard Self.normalized(modifiers) == Self.normalized(eventModifiers) else {
            return false
        }

        if let keyEquivalent {
            return key == keyEquivalent
        }

        guard let expectedCharacters = expectedCharacters else {
            return false
        }

        return characters.lowercased() == expectedCharacters.lowercased()
    }
}

extension TriggerShortcut {
    init?(raw: RawShortcutConfig) {
        guard
            let rawKey = raw.key?.trimmingCharacters(in: .whitespacesAndNewlines),
            !rawKey.isEmpty,
            let key = Key(string: rawKey),
            !Self.isModifierKey(key)
        else {
            return nil
        }

        guard let rawModifiers = raw.modifiers, !rawModifiers.isEmpty else {
            return nil
        }

        var modifiers: NSEvent.ModifierFlags = []
        for rawModifier in rawModifiers {
            guard let modifier = Self.modifierFlag(from: rawModifier) else {
                return nil
            }
            modifiers.insert(modifier)
        }

        guard !modifiers.isEmpty else {
            return nil
        }

        self.init(key: key, modifiers: modifiers)
    }
}

private extension TriggerShortcut {
    var keyEquivalent: KeyEquivalent? {
        switch key {
        case .a: return "a"
        case .b: return "b"
        case .c: return "c"
        case .d: return "d"
        case .e: return "e"
        case .f: return "f"
        case .g: return "g"
        case .h: return "h"
        case .i: return "i"
        case .j: return "j"
        case .k: return "k"
        case .l: return "l"
        case .m: return "m"
        case .n: return "n"
        case .o: return "o"
        case .p: return "p"
        case .q: return "q"
        case .r: return "r"
        case .s: return "s"
        case .t: return "t"
        case .u: return "u"
        case .v: return "v"
        case .w: return "w"
        case .x: return "x"
        case .y: return "y"
        case .z: return "z"
        case .zero: return "0"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .period: return "."
        case .quote: return "\""
        case .rightBracket: return "]"
        case .semicolon: return ";"
        case .slash: return "/"
        case .backslash: return "\\"
        case .comma: return ","
        case .equal: return "="
        case .grave: return "`"
        case .leftBracket: return "["
        case .minus: return "-"
        case .section: return "§"
        case .space: return .space
        case .tab: return .tab
        case .return: return .return
        case .pageUp: return .pageUp
        case .pageDown: return .pageDown
        case .home: return .home
        case .end: return .end
        case .upArrow: return .upArrow
        case .rightArrow: return .rightArrow
        case .downArrow: return .downArrow
        case .leftArrow: return .leftArrow
        case .escape: return .escape
        case .delete: return .delete
        case .forwardDelete: return .deleteForward
        default: return nil
        }
    }

    var eventModifiers: EventModifiers {
        var modifiers: EventModifiers = []

        if self.modifiers.contains(.command) {
            modifiers.insert(.command)
        }
        if self.modifiers.contains(.option) {
            modifiers.insert(.option)
        }
        if self.modifiers.contains(.control) {
            modifiers.insert(.control)
        }
        if self.modifiers.contains(.shift) {
            modifiers.insert(.shift)
        }

        return modifiers
    }

    var expectedCharacters: String? {
        switch key {
        case .space: return " "
        case .tab: return "\t"
        case .return: return "\r"
        case .a, .b, .c, .d, .e, .f, .g, .h, .i, .j, .k, .l, .m,
             .n, .o, .p, .q, .r, .s, .t, .u, .v, .w, .x, .y, .z,
             .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine,
             .period, .quote, .rightBracket, .semicolon, .slash, .backslash, .comma,
             .equal, .grave, .leftBracket, .minus, .section:
            return keyEquivalent.map { String($0.character) }
        default:
            return nil
        }
    }

    static func normalized(_ modifiers: EventModifiers) -> EventModifiers {
        var normalized: EventModifiers = []

        if modifiers.contains(.command) {
            normalized.insert(.command)
        }
        if modifiers.contains(.option) {
            normalized.insert(.option)
        }
        if modifiers.contains(.control) {
            normalized.insert(.control)
        }
        if modifiers.contains(.shift) {
            normalized.insert(.shift)
        }

        return normalized
    }

    static func modifierFlag(from value: String) -> NSEvent.ModifierFlags? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "command":
            return .command
        case "option":
            return .option
        case "control":
            return .control
        case "shift":
            return .shift
        default:
            return nil
        }
    }

    static func isModifierKey(_ key: Key) -> Bool {
        switch key {
        case .command, .rightCommand, .option, .rightOption, .control, .rightControl, .shift, .rightShift, .function, .capsLock:
            return true
        default:
            return false
        }
    }
}
