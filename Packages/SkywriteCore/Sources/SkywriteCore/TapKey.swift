public enum TapKey: String, Codable, CaseIterable, Sendable {
    /// Pressing a key twice doesn't make a note. New installs start here, so Skywrite asks for no Accessibility permission
    /// until you choose a key (user decision, 2026-11-07).
    case off
    case eitherOption
    case rightOption
    case rightCommand

    public func matches(keyCode: UInt16) -> Bool {
        switch self {
        case .off:
            false
        case .rightOption:
            keyCode == ModifierKey.rightOption.keyCode
        case .rightCommand:
            keyCode == ModifierKey.rightCommand.keyCode
        case .eitherOption:
            keyCode == ModifierKey.leftOption.keyCode || keyCode == ModifierKey.rightOption.keyCode
        }
    }
}
