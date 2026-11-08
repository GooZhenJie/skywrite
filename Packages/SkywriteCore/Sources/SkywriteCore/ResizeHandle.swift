public enum ResizeHandle: CaseIterable, Sendable {
    case top
    case bottom
    case left
    case right
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    public var movesTop: Bool { self == .top || self == .topLeft || self == .topRight }
    public var movesBottom: Bool { self == .bottom || self == .bottomLeft || self == .bottomRight }
    public var movesLeft: Bool { self == .left || self == .topLeft || self == .bottomLeft }
    public var movesRight: Bool { self == .right || self == .topRight || self == .bottomRight }
    public var changesWidth: Bool { movesLeft || movesRight }
    public var changesHeight: Bool { movesTop || movesBottom }
    public var isCorner: Bool { changesWidth && changesHeight }
}
