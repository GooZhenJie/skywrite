import CoreGraphics
import Foundation

public enum NoteGeometry {
    public static func requestedSize(start: CGRect, handle: ResizeHandle, translation: CGVector, minimumSize: CGSize) -> CGSize {
        var width = start.width
        var height = start.height
        if handle.movesRight { width += translation.dx }
        if handle.movesLeft { width -= translation.dx }
        if handle.movesTop { height += translation.dy }
        if handle.movesBottom { height -= translation.dy }
        return CGSize(width: max(minimumSize.width, width), height: max(minimumSize.height, height))
    }

    public static func anchoredBox(start: CGRect, handle: ResizeHandle, size: CGSize) -> CGRect {
        let x = handle.movesLeft ? start.maxX - size.width : start.minX
        let y = handle.movesTop ? start.minY : start.maxY - size.height
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    public static func zoomedPoint(_ point: CGPoint, around anchor: CGPoint, factor: CGFloat) -> CGPoint {
        CGPoint(x: anchor.x - (anchor.x - point.x) * factor, y: anchor.y - (anchor.y - point.y) * factor)
    }

    public static func clampedZoom(_ zoom: Double) -> Double {
        min(NoteMetrics.maximumZoom, max(NoteMetrics.minimumZoom, zoom))
    }

    /// The zoom a note can grow to without getting bigger than its screen. Past that, part of the note is always out of
    /// sight: nothing shows beyond a screen's edge, and with "Displays have separate Spaces" on, macOS draws a window on
    /// one display only, so a note zoomed too far loses part or all of itself. Zooming out is never
    /// held back, and a note that's already bigger than its screen stays as it is rather than shrinking.
    ///
    /// `box` is the note's size at `currentZoom`; a note grows in proportion to its zoom.
    public static func zoomFitting(_ requested: Double, currentZoom: Double, box: CGSize, in screen: CGSize) -> Double {
        guard requested > currentZoom, box.width > 0, box.height > 0 else { return requested }
        let fit = currentZoom * Double(min(screen.width / box.width, screen.height / box.height))
        return max(currentZoom, min(requested, fit))
    }

    /// `box` moved as little as it takes to be inside `bounds`. When it's wider or taller than `bounds`, its left or top
    /// edge lines up with the edge of `bounds`, so the start of its text stays in sight.
    public static func moved(_ box: CGRect, inside bounds: CGRect) -> CGRect {
        let x = max(bounds.minX, min(box.minX, bounds.maxX - box.width))
        let top = min(bounds.maxY, max(box.maxY, bounds.minY + box.height))
        return CGRect(x: x, y: top - box.height, width: box.width, height: box.height)
    }

    public static func scrollZoomFactor(deltaY: Double, hasPreciseDeltas: Bool) -> Double {
        let sensitivity = hasPreciseDeltas ? NoteMetrics.preciseScrollZoomSensitivity : NoteMetrics.lineScrollZoomSensitivity
        return exp(deltaY * sensitivity)
    }

    public static func autoWidthLimit(boxMinX: CGFloat, screenMaxX: CGFloat) -> CGFloat {
        max(NoteMetrics.minimumFixedWidth, screenMaxX - boxMinX - NoteMetrics.screenEdgeMargin)
    }

    /// A note created with a click grows with its text only until it's locked for the first time. From then on its width
    /// stays put, wherever it's dragged and whatever is typed into it, until the user resizes it; its height still follows
    /// the text. Returns the width to keep, in unzoomed points, or the note's own fixed width if it already has one.
    public static func widthAfterLocking(fixedWidth: Double?, boxWidth: CGFloat, zoom: CGFloat) -> Double {
        fixedWidth ?? Double(boxWidth / zoom)
    }

    /// The first line is centred on the click and the text starts at the same spot whatever the padding, so a roomier
    /// background grows out around the text instead of pushing it away from where you clicked.
    public static func placedBox(clickPoint: CGPoint, lineHeight: CGFloat, padding: CGSize = CGSize(width: NoteMetrics.textHorizontalPadding, height: NoteMetrics.textVerticalPadding)) -> CGPoint {
        CGPoint(x: clickPoint.x + NoteMetrics.textHorizontalPadding - padding.width, y: clickPoint.y + lineHeight / 2 + padding.height)
    }

    public static func draggedBox(from start: CGPoint, to end: CGPoint, lineHeight: CGFloat, verticalPadding: CGFloat = NoteMetrics.textVerticalPadding) -> NotePlacement {
        let width = abs(end.x - start.x)
        let height = abs(end.y - start.y)
        let fixedWidth = width > NoteMetrics.dragThreshold ? max(NoteMetrics.minimumFixedWidth, width) : nil
        let minimumHeight = height > lineHeight + verticalPadding * 2 ? height : nil
        return NotePlacement(topLeft: CGPoint(x: min(start.x, end.x), y: max(start.y, end.y)), fixedWidth: fixedWidth, minimumHeight: minimumHeight)
    }

    public static func isDrag(from start: CGPoint, to end: CGPoint) -> Bool {
        abs(end.x - start.x) > NoteMetrics.dragThreshold || abs(end.y - start.y) > NoteMetrics.dragThreshold
    }
}
