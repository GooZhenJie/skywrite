import CoreGraphics

public enum ScreenPlacement {
    public static func topLeftBringingBack(_ box: CGRect, into visibleFrame: CGRect) -> CGPoint {
        let margin = NoteMetrics.screenEdgeMargin
        let width = min(box.width, visibleFrame.width - margin * 2)
        let height = min(box.height, visibleFrame.height - margin * 2)
        let x = min(max(box.minX, visibleFrame.minX + margin), visibleFrame.maxX - margin - width)
        let top = min(max(box.maxY, visibleFrame.minY + margin + height), visibleFrame.maxY - margin)
        return CGPoint(x: x, y: top)
    }

    /// `box` moved as little as it takes for at least `NoteMetrics.keptInSight` of it each way (all of it, when it's
    /// smaller) to show inside one of `areas`, the screens' visible frames. A note may hang past any edge of a screen, but never so far that there's nothing left to see or grab.
    /// The area it's pulled into is the one it overlaps most, or the nearest one when it overlaps none, such as in the gap
    /// beside a smaller screen.
    public static func keepingVisible(_ box: CGRect, in areas: [CGRect]) -> CGRect {
        let needed = CGSize(width: min(NoteMetrics.keptInSight, box.width), height: min(NoteMetrics.keptInSight, box.height))
        func shows(_ area: CGRect) -> Bool {
            let overlap = area.intersection(box)
            return !overlap.isNull && overlap.width >= needed.width && overlap.height >= needed.height
        }
        guard !areas.isEmpty, !areas.contains(where: shows) else { return box }
        let frame = areas.max { score($0, box) < score($1, box) }!
        let x = min(max(box.minX, frame.minX - box.width + needed.width), frame.maxX - needed.width)
        let y = min(max(box.minY, frame.minY - box.height + needed.height), frame.maxY - needed.height)
        return CGRect(x: x, y: y, width: box.width, height: box.height)
    }

    /// Larger for the frame `box` overlaps more; among frames it doesn't overlap, larger for the nearer one.
    private static func score(_ frame: CGRect, _ box: CGRect) -> CGFloat {
        let overlap = frame.intersection(box)
        if !overlap.isNull, overlap.width > 0, overlap.height > 0 {
            return overlap.width * overlap.height
        }
        let dx = max(frame.minX - box.maxX, box.minX - frame.maxX, 0)
        let dy = max(frame.minY - box.maxY, box.minY - frame.maxY, 0)
        return -hypot(dx, dy)
    }

    /// True when all of `box` is inside one of `visibleFrames`.
    public static func isWhollyVisible(_ box: CGRect, in visibleFrames: [CGRect]) -> Bool {
        visibleFrames.contains { $0.contains(box) }
    }

    /// The zoom at which a note of `box` at `zoom` fits inside `visibleFrame` with `NoteMetrics.screenEdgeMargin` on
    /// every side: `zoom` itself when it already fits, smaller when it doesn't.
    public static func zoomFitting(_ box: CGSize, zoom: Double, in visibleFrame: CGRect) -> Double {
        let margin = NoteMetrics.screenEdgeMargin * 2
        guard box.width > 0, box.height > 0 else { return zoom }
        let scale = min(1, (visibleFrame.width - margin) / box.width, (visibleFrame.height - margin) / box.height)
        return NoteGeometry.clampedZoom(zoom * Double(scale))
    }
}
