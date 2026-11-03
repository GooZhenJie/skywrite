public enum TapKey: String, Codable, CaseIterable, Sendable {
    case rightOption
    case rightCommand
    case eitherOption

    public func matches(keyCode: UInt16) -> Bool {
        switch self {
        case .rightOption:
            keyCode == ModifierKey.rightOption.keyCode
        case .rightCommand:
            keyCode == ModifierKey.rightCommand.keyCode
        case .eitherOption:
            keyCode == ModifierKey.leftOption.keyCode || keyCode == ModifierKey.rightOption.keyCode
        }
    }
}
