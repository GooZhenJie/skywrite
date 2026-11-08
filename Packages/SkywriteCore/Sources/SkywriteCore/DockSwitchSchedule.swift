import Foundation

/// Spaces out Dock icon switches. Switching the activation policy back and forth faster than macOS finishes
/// the previous switch leaves extra Dock icons behind, so requests that arrive too soon are held and merged.
public struct DockSwitchSchedule: Sendable {
    /// Electron waits one second between showing and hiding the Dock icon for the same macOS bug
    /// (`Browser::DockHide` in shell/browser/browser_mac.mm: "After some experiments, 1 second seems to be a proper interval").
    public static let standardMinimumInterval: TimeInterval = 1

    public let minimumInterval: TimeInterval
    public private(set) var applied: Bool
    public private(set) var desired: Bool
    private var lastSwitch: TimeInterval?

    public init(applied: Bool, minimumInterval: TimeInterval = DockSwitchSchedule.standardMinimumInterval) {
        self.applied = applied
        self.desired = applied
        self.minimumInterval = minimumInterval
    }

    /// Records the newest request and returns how long to wait before calling `fire`, or nil when nothing has to change.
    public mutating func request(_ visible: Bool, now: TimeInterval) -> TimeInterval? {
        desired = visible
        return delay(now: now)
    }

    public func delay(now: TimeInterval) -> TimeInterval? {
        guard desired != applied else { return nil }
        guard let lastSwitch else { return 0 }
        return max(0, lastSwitch + minimumInterval - now)
    }

    /// Returns the visibility to apply now, or nil when the request was undone or it is still too early.
    public mutating func fire(now: TimeInterval) -> Bool? {
        guard delay(now: now) == 0 else { return nil }
        applied = desired
        lastSwitch = now
        return applied
    }
}
