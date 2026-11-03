import Foundation

public struct DoubleTapDetector: Sendable {
    public var key: TapKey
    public var interval: TimeInterval
    private var tapKeyIsDown = false
    private var pressWasInterrupted = false
    private var lastTapEnd: TimeInterval?

    public init(key: TapKey, interval: TimeInterval) {
        self.key = key
        self.interval = interval
    }

    public mutating func modifierChanged(keyCode: UInt16, isDown: Bool, otherModifiersDown: Bool, at time: TimeInterval) -> Bool {
        guard key.matches(keyCode: keyCode) else {
            interrupt()
            return false
        }
        if isDown {
            tapKeyIsDown = true
            pressWasInterrupted = otherModifiersDown
            return false
        }
        guard tapKeyIsDown else { return false }
        tapKeyIsDown = false
        if pressWasInterrupted {
            lastTapEnd = nil
            return false
        }
        if let lastTapEnd, time - lastTapEnd <= interval {
            self.lastTapEnd = nil
            return true
        }
        lastTapEnd = time
        return false
    }

    public mutating func interrupt() {
        if tapKeyIsDown {
            pressWasInterrupted = true
        }
        lastTapEnd = nil
    }
}
