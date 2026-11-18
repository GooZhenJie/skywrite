import AppKit
import SkywriteCore

/// Writes down what happens while a note is dragged or zoomed, so a drag that stutters or a note that changes size can be
/// checked against the log afterwards: one line when a drag starts, one when it ends, and one per zoom gesture.
final class NoteInputLog {
    private struct Drag {
        let note: String
        let startedAt: TimeInterval
        let startMouse: CGPoint
        let startSize: CGSize
        var events = 0
        var lastMouse: CGPoint
        var lastTimestamp: TimeInterval
        var longestLag: TimeInterval = 0
        var biggestStep: CGFloat = 0
        var biggestStepGap: TimeInterval = 0
        var lastSetOrigin: CGPoint?
        var movedByOthers = 0
        var largestSizeChange: CGFloat = 0
    }

    private struct Zoom {
        let note: String
        let from: Double
        var to: Double
        var events: Int
        let source: String
    }

    /// A zoom gesture is over once no zoom has come in for this long: longer than the gap between two
    /// scroll events of one gesture, short enough that two separate gestures get two lines.
    private static let zoomGestureEnd: TimeInterval = 0.6
    private var drag: Drag?
    private var zoom: Zoom?
    private var zoomFlush: DispatchWorkItem?

    /// `box` is the note's box on screen and `pressedAt` where the button went down, in screen coordinates.
    func dragPressed(window: NSWindow, box: CGRect, zoom: Double, pressedAt: CGPoint, pressTime: TimeInterval) {
        let note = window.identifier?.rawValue ?? "note"
        let mouse = NSEvent.mouseLocation
        let handledAfter = ProcessInfo.processInfo.systemUptime - pressTime
        drag = Drag(note: note, startedAt: pressTime, startMouse: pressedAt, startSize: window.frame.size, lastMouse: pressedAt, lastTimestamp: pressTime)
        EventLog.input.notice("drag press \(note, privacy: .public) grab=\(Self.point(CGPoint(x: pressedAt.x - box.minX, y: box.maxY - pressedAt.y)), privacy: .public) from the box's top-left, box=\(Self.size(box.size), privacy: .public) at \(Self.point(box.origin), privacy: .public) zoom=\(String(format: "%.3f", zoom), privacy: .public) handled after \(Self.milliseconds(handledAfter), privacy: .public), mouse had moved \(Self.point(CGPoint(x: mouse.x - pressedAt.x, y: mouse.y - pressedAt.y)), privacy: .public)")
    }

    /// Called for every drag event the note handles, before it moves the window.
    func dragEvent(_ event: NSEvent, window: NSWindow) {
        guard var current = drag else { return }
        let mouse = NSEvent.mouseLocation
        current.events += 1
        current.longestLag = max(current.longestLag, ProcessInfo.processInfo.systemUptime - event.timestamp)
        let step = hypot(mouse.x - current.lastMouse.x, mouse.y - current.lastMouse.y)
        if step > current.biggestStep {
            current.biggestStep = step
            current.biggestStepGap = event.timestamp - current.lastTimestamp
        }
        current.lastMouse = mouse
        current.lastTimestamp = event.timestamp
        if let lastSet = current.lastSetOrigin, hypot(window.frame.origin.x - lastSet.x, window.frame.origin.y - lastSet.y) > 0.5 {
            current.movedByOthers += 1
        }
        current.largestSizeChange = max(current.largestSizeChange, abs(window.frame.width - current.startSize.width), abs(window.frame.height - current.startSize.height))
        drag = current
    }

    func dragMoved(window: NSWindow) {
        drag?.lastSetOrigin = window.frame.origin
    }

    /// `boxBefore` and `boxAfter` are the box just before and after the note settled where it was dropped.
    func dragEnded(moved: Bool, endedBy event: NSEvent?, boxBefore: CGRect, boxAfter: CGRect) {
        guard let current = drag else { return }
        drag = nil
        let now = ProcessInfo.processInfo.systemUptime
        let mouse = NSEvent.mouseLocation
        let grabNow = CGPoint(x: mouse.x - boxAfter.minX, y: boxAfter.maxY - mouse.y)
        let ending = event.map { $0.type == .leftMouseUp ? "mouse up" : "event \($0.type.rawValue)" } ?? "no event"
        EventLog.input.notice("drag end \(current.note, privacy: .public) moved=\(moved, privacy: .public) by=\(ending, privacy: .public) buttonsHeld=\(NSEvent.pressedMouseButtons, privacy: .public) duration=\(Self.milliseconds(now - current.startedAt), privacy: .public) events=\(current.events, privacy: .public) distance=\(Self.point(CGPoint(x: mouse.x - current.startMouse.x, y: mouse.y - current.startMouse.y)), privacy: .public) longestLag=\(Self.milliseconds(current.longestLag), privacy: .public) biggestStep=\(String(format: "%.0f", current.biggestStep), privacy: .public)pt in \(Self.milliseconds(current.biggestStepGap), privacy: .public) movedByOthers=\(current.movedByOthers, privacy: .public) sizeChange=\(String(format: "%.1f", current.largestSizeChange), privacy: .public)pt box before=\(Self.size(boxBefore.size), privacy: .public) after=\(Self.size(boxAfter.size), privacy: .public) at \(Self.point(boxAfter.origin), privacy: .public) grab now=\(Self.point(grabNow), privacy: .public)")
    }

    func zoomed(note: String, from: Double, to: Double, source: String) {
        guard from != to else { return }
        if var current = zoom, current.note == note, current.source == source {
            current.to = to
            current.events += 1
            zoom = current
        } else {
            flushZoom()
            zoom = Zoom(note: note, from: from, to: to, events: 1, source: source)
        }
        zoomFlush?.cancel()
        let flush = DispatchWorkItem { [weak self] in self?.flushZoom() }
        zoomFlush = flush
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.zoomGestureEnd, execute: flush)
    }

    private func flushZoom() {
        guard let current = zoom else { return }
        zoom = nil
        EventLog.input.notice("zoom \(current.note, privacy: .public) \(String(format: "%.3f", current.from), privacy: .public) -> \(String(format: "%.3f", current.to), privacy: .public) by=\(current.source, privacy: .public) events=\(current.events, privacy: .public) frontmost=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown", privacy: .public)")
    }

    private static func point(_ point: CGPoint) -> String {
        String(format: "(%.0f, %.0f)", point.x, point.y)
    }

    private static func size(_ size: CGSize) -> String {
        String(format: "%.0fx%.0f", size.width, size.height)
    }

    private static func milliseconds(_ seconds: TimeInterval) -> String {
        String(format: "%.0fms", seconds * 1000)
    }
}
