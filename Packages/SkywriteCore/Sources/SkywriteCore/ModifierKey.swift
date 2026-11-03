public enum ModifierKey: CaseIterable, Sendable {
    case leftControl
    case rightControl
    case leftShift
    case rightShift
    case leftCommand
    case rightCommand
    case leftOption
    case rightOption

    public var keyCode: UInt16 {
        switch self {
        case .leftControl: 0x3B
        case .rightControl: 0x3E
        case .leftShift: 0x38
        case .rightShift: 0x3C
        case .leftCommand: 0x37
        case .rightCommand: 0x36
        case .leftOption: 0x3A
        case .rightOption: 0x3D
        }
    }

    public var deviceMask: UInt {
        switch self {
        case .leftControl: 0x0000_0001
        case .rightControl: 0x0000_2000
        case .leftShift: 0x0000_0002
        case .rightShift: 0x0000_0004
        case .leftCommand: 0x0000_0008
        case .rightCommand: 0x0000_0010
        case .leftOption: 0x0000_0020
        case .rightOption: 0x0000_0040
        }
    }

    public init?(keyCode: UInt16) {
        guard let key = Self.allCases.first(where: { $0.keyCode == keyCode }) else { return nil }
        self = key
    }

    public static func isDown(keyCode: UInt16, deviceFlags: UInt) -> Bool? {
        guard let key = ModifierKey(keyCode: keyCode) else { return nil }
        return deviceFlags & key.deviceMask != 0
    }

    public static func othersAreDown(besides keyCode: UInt16, deviceFlags: UInt) -> Bool {
        allCases.contains { $0.keyCode != keyCode && deviceFlags & $0.deviceMask != 0 }
    }
}
