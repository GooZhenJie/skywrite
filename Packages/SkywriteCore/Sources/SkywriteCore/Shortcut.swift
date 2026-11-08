public struct Shortcut: Codable, Equatable, Hashable, Sendable {
    public var keyCode: UInt32
    public var carbonModifiers: UInt32
    public var keyLabel: String

    public init(keyCode: UInt32, carbonModifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.keyLabel = keyLabel
    }

    public static let controlFlag: UInt32 = 0x1000
    public static let optionFlag: UInt32 = 0x0800
    public static let shiftFlag: UInt32 = 0x0200
    public static let commandFlag: UInt32 = 0x0100

    public var symbols: [String] {
        var result: [String] = []
        if carbonModifiers & Self.controlFlag != 0 { result.append("⌃") }
        if carbonModifiers & Self.optionFlag != 0 { result.append("⌥") }
        if carbonModifiers & Self.shiftFlag != 0 { result.append("⇧") }
        if carbonModifiers & Self.commandFlag != 0 { result.append("⌘") }
        result.append(keyLabel.uppercased())
        return result
    }

    public var hasModifier: Bool {
        carbonModifiers & (Self.controlFlag | Self.optionFlag | Self.commandFlag) != 0
    }
}

public enum ShortcutAction: String, Codable, CaseIterable, Sendable {
    case newNote
    case toggleAllNotes
    case reopenClosedNote

    public var defaultShortcut: Shortcut {
        let modifiers = Shortcut.controlFlag | Shortcut.optionFlag
        switch self {
        case .newNote: return Shortcut(keyCode: 0x2D, carbonModifiers: modifiers, keyLabel: "N")
        case .toggleAllNotes: return Shortcut(keyCode: 0x04, carbonModifiers: modifiers, keyLabel: "H")
        case .reopenClosedNote: return Shortcut(keyCode: 0x06, carbonModifiers: modifiers, keyLabel: "Z")
        }
    }
}
