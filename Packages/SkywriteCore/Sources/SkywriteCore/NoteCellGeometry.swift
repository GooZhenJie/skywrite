import CoreGraphics

/// The space around the cells of a note and between them, and the space between each cell's edge and its text.
public struct NoteCellSpacing: Equatable, Sendable {
    /// Between the box's edge and the cells along it.
    public var margin: CGSize
    /// Between neighbouring cells.
    public var gap: CGSize
    /// Between a cell's edge and its text.
    public var padding: CGSize

    public init(margin: CGSize, gap: CGSize, padding: CGSize) {
        self.margin = margin
        self.gap = gap
        self.padding = padding
    }
}

/// Where each cell of a note goes. All sizes are in screen points; frames are measured from the box's top-left corner,
/// with y growing downwards. A plain note is a single cell that fills the box.
public enum NoteCellGeometry {
    /// The spacing for a note with this layout, given the space a plain note leaves around its text (`textPadding`).
    ///
    /// A plain note's one cell fills the box. In a note with cells, each cell is drawn as a lighter rounded tile: the text
    /// stays as far from the note's edge as in a plain note, and the tile's edge sits part of the way out
    /// (`NoteMetrics.cellTileInsetShare`), so the text is the same distance inside its tile on every side. Tiles are as far
    /// apart as they are from the edge, whatever the font size.
    public static func spacing(layout: NoteLayout, textPadding: CGSize) -> NoteCellSpacing {
        guard layout.isGrid else { return NoteCellSpacing(margin: .zero, gap: .zero, padding: textPadding) }
        let share = NoteMetrics.cellTileInsetShare
        let margin = CGSize(width: textPadding.width * share, height: textPadding.height * share)
        let padding = CGSize(width: textPadding.width - margin.width, height: textPadding.height - margin.height)
        return NoteCellSpacing(margin: margin, gap: margin, padding: padding)
    }

    /// How wide each cell in a row of `count` cells is when the box is `boxWidth` wide.
    public static func cellWidth(boxWidth: CGFloat, count: Int, spacing: NoteCellSpacing) -> CGFloat {
        guard count > 0 else { return boxWidth }
        return max(0, (boxWidth - spacing.margin.width * 2 - spacing.gap.width * CGFloat(count - 1)) / CGFloat(count))
    }

    /// How wide the box must be for every cell to fit `cellWidths`, the width each cell would like. Cells in a row share
    /// the width evenly, so the row with the widest cell for its count decides.
    public static func boxWidth(layout: NoteLayout, cellWidths: [CGFloat], spacing: NoteCellSpacing) -> CGFloat {
        let widestRow = layout.rows.map { row in
            let widest = row.map { cellWidths.indices.contains($0) ? cellWidths[$0] : 0 }.max() ?? 0
            return widest * CGFloat(row.count) + spacing.gap.width * CGFloat(row.count - 1)
        }.max() ?? 0
        return widestRow + spacing.margin.width * 2
    }

    /// The frame of every cell, and the height of the cells' content without any extra height the box was stretched to.
    ///
    /// A row is as tall as its tallest cell, and every cell in it takes that height so a click anywhere in the cell lands
    /// in it. When the box must be taller than the content (`minimumBoxHeight`), each row gets an equal share of the rest.
    public static func cellFrames(layout: NoteLayout, boxWidth: CGFloat, cellHeights: [CGFloat], minimumBoxHeight: CGFloat, spacing: NoteCellSpacing) -> (frames: [CGRect], contentHeight: CGFloat) {
        let rows = layout.rows
        let rowHeights = rows.map { row in row.map { cellHeights.indices.contains($0) ? cellHeights[$0] : 0 }.max() ?? 0 }
        let contentHeight = rowHeights.reduce(0, +) + spacing.gap.height * CGFloat(rows.count - 1) + spacing.margin.height * 2
        let extraPerRow = max(0, minimumBoxHeight - contentHeight) / CGFloat(rows.count)
        var frames: [CGRect] = []
        var top = spacing.margin.height
        for (row, rowHeight) in zip(rows, rowHeights) {
            let width = cellWidth(boxWidth: boxWidth, count: row.count, spacing: spacing)
            let height = rowHeight + extraPerRow
            for position in 0..<row.count {
                frames.append(CGRect(x: spacing.margin.width + (width + spacing.gap.width) * CGFloat(position), y: top, width: width, height: height))
            }
            top += height + spacing.gap.height
        }
        return (frames, contentHeight)
    }
}
