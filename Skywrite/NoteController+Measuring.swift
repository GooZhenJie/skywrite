import AppKit
import SkywriteCore

/// Measuring a note's text to size its box and place its cells.
extension NoteController {
    private var screenFrame: CGRect {
        let screen = NSScreen.screens.first { $0.frame.contains(topLeft) } ?? NSScreen.main ?? NSScreen.screens.first
        return screen?.visibleFrame ?? .zero
    }

    /// Measures every cell and works out the box: its size, and where each cell goes in it (`cellFrames`).
    ///
    /// Without a fixed width the box is as wide as the text in it, up to the screen edge; cells in a row share the width
    /// evenly, so the cell with the most text decides. A row is as tall as its tallest cell. A plain note is one cell,
    /// which comes out exactly as wide and tall as its text plus padding.
    func measuredBoxSize() -> CGSize {
        applyTextAttributes()
        let font = style.font(zoom: zoom)
        let spacing = NoteCellGeometry.spacing(layout: layout, textPadding: style.textPadding(zoom: zoom))
        let padding = spacing.padding
        let fixedWidth = record.fixedWidth.map { CGFloat($0) * zoom }
        let widthLimit = fixedWidth ?? NoteGeometry.autoWidthLimit(boxMinX: topLeft.x, screenMaxX: screenFrame.maxX)
        var textSizes = [CGSize](repeating: .zero, count: cellViews.count)
        for row in layout.rows {
            let cellLimit = NoteCellGeometry.cellWidth(boxWidth: widthLimit, count: row.count, spacing: spacing)
            for index in row {
                cellViews[index].textContainerInset = padding
                textSizes[index] = NoteTextLayout.textSize(of: cellViews[index], widthLimit: cellLimit - padding.width * 2, font: font)
            }
        }
        let width = fixedWidth ?? NoteCellGeometry.boxWidth(layout: layout, cellWidths: textSizes.map { max(NoteMetrics.minimumTextWidth, $0.width + padding.width * 2) }, spacing: spacing)
        let minimumHeight = record.minimumHeight.map { CGFloat($0) * zoom } ?? 0
        let cells = NoteCellGeometry.cellFrames(layout: layout, boxWidth: width, cellHeights: textSizes.map { $0.height + padding.height * 2 }, minimumBoxHeight: minimumHeight, spacing: spacing)
        cellFrames = cells.frames
        textContentHeight = cells.contentHeight
        return CGSize(width: width, height: max(textContentHeight, minimumHeight))
    }
}

extension NoteController {
    /// Shrinks the note if it's bigger than `visibleFrame` and moves it all the way inside, `NoteMetrics.screenEdgeMargin`
    /// from the edges.
    func bringWhollyOnScreen(_ visibleFrame: CGRect) {
        let fitting = ScreenPlacement.zoomFitting(boxInScreen.size, zoom: record.zoom, in: visibleFrame)
        if fitting < record.zoom {
            record.zoom = fitting
            relayoutKeepingTopLeft()
        }
        move(toTopLeft: ScreenPlacement.topLeftBringingBack(boxInScreen, into: visibleFrame))
    }
}
