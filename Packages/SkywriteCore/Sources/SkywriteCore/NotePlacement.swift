import CoreGraphics

public struct NotePlacement: Equatable, Sendable {
    public var topLeft: CGPoint
    public var fixedWidth: CGFloat?
    public var minimumHeight: CGFloat?

    public init(topLeft: CGPoint, fixedWidth: CGFloat? = nil, minimumHeight: CGFloat? = nil) {
        self.topLeft = topLeft
        self.fixedWidth = fixedWidth
        self.minimumHeight = minimumHeight
    }
}
