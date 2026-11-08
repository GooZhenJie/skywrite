import CoreGraphics

public enum ScreenPlacement {
    public static func isVisible(_ box: CGRect, on screenFrames: [CGRect]) -> Bool {
        screenFrames.contains { $0.intersects(box) }
    }

    public static func topLeftBringingBack(_ box: CGRect, into visibleFrame: CGRect) -> CGPoint {
        let margin = NoteMetrics.screenEdgeMargin
        let width = min(box.width, visibleFrame.width - margin * 2)
        let height = min(box.height, visibleFrame.height - margin * 2)
        let x = min(max(box.minX, visibleFrame.minX + margin), visibleFrame.maxX - margin - width)
        let top = min(max(box.maxY, visibleFrame.minY + margin + height), visibleFrame.maxY - margin)
        return CGPoint(x: x, y: top)
    }
}
