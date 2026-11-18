import CoreGraphics
import Testing
@testable import SkywriteCore

struct NoteCellGeometryTests {
    let spacing = NoteCellSpacing(margin: .zero, gap: CGSize(width: 12, height: 16), padding: .zero)

    @Test func singleCellFillsTheBox() {
        let result = NoteCellGeometry.cellFrames(layout: .single, boxWidth: 200, cellHeights: [40], minimumBoxHeight: 0, spacing: spacing)
        #expect(result.frames == [CGRect(x: 0, y: 0, width: 200, height: 40)])
        #expect(result.contentHeight == 40)
    }

    @Test func rowIsAsTallAsItsTallestCell() {
        let result = NoteCellGeometry.cellFrames(layout: .twoByTwo, boxWidth: 212, cellHeights: [20, 60, 30, 10], minimumBoxHeight: 0, spacing: spacing)
        #expect(result.frames == [
            CGRect(x: 0, y: 0, width: 100, height: 60),
            CGRect(x: 112, y: 0, width: 100, height: 60),
            CGRect(x: 0, y: 76, width: 100, height: 30),
            CGRect(x: 112, y: 76, width: 100, height: 30)
        ])
        #expect(result.contentHeight == 106)
    }

    @Test func extraHeightIsSharedByTheRows() {
        let result = NoteCellGeometry.cellFrames(layout: .twoByTwo, boxWidth: 212, cellHeights: [20, 20, 20, 20], minimumBoxHeight: 96, spacing: spacing)
        #expect(result.frames.map(\.height) == [40, 40, 40, 40])
        #expect(result.contentHeight == 56)
    }

    @Test func singleCellInARowSpansTheWidth() throws {
        let layout = try #require(NoteLayout(cellsPerRow: [2, 1]))
        let result = NoteCellGeometry.cellFrames(layout: layout, boxWidth: 212, cellHeights: [20, 20, 20], minimumBoxHeight: 0, spacing: spacing)
        #expect(result.frames[2] == CGRect(x: 0, y: 36, width: 212, height: 20))
    }

    @Test func boxIsWideEnoughForTheWidestCell() throws {
        #expect(NoteCellGeometry.boxWidth(layout: .single, cellWidths: [80], spacing: spacing) == 80)
        #expect(NoteCellGeometry.boxWidth(layout: .twoByTwo, cellWidths: [30, 80, 50, 20], spacing: spacing) == 172)
        let layout = try #require(NoteLayout(cellsPerRow: [2, 1]))
        #expect(NoteCellGeometry.boxWidth(layout: layout, cellWidths: [30, 30, 200], spacing: spacing) == 200)
        let withMargin = NoteCellSpacing(margin: CGSize(width: 6, height: 6), gap: CGSize(width: 8, height: 8), padding: .zero)
        #expect(NoteCellGeometry.boxWidth(layout: .twoByTwo, cellWidths: [30, 80, 50, 20], spacing: withMargin) == 180)
    }

    @Test func plainNoteKeepsItsPadding() {
        let plain = NoteCellGeometry.spacing(layout: .single, textPadding: CGSize(width: 12, height: 12))
        #expect(plain.margin == .zero)
        #expect(plain.padding == CGSize(width: 12, height: 12))
    }

    /// Liquid Glass: the text is 12pt from the note's edge as in a plain note, the tile halfway out, and the tiles are as
    /// far apart as they are from the edge.
    @Test func tilesSitHalfwayBetweenTheEdgeAndTheText() {
        let grid = NoteCellGeometry.spacing(layout: .twoByTwo, textPadding: CGSize(width: 12, height: 12))
        #expect(grid == NoteCellSpacing(margin: CGSize(width: 6, height: 6), gap: CGSize(width: 6, height: 6), padding: CGSize(width: 6, height: 6)))
        let result = NoteCellGeometry.cellFrames(layout: .twoByTwo, boxWidth: 520, cellHeights: [150, 150, 150, 150], minimumBoxHeight: 0, spacing: grid)
        #expect(result.frames == [
            CGRect(x: 6, y: 6, width: 251, height: 150),
            CGRect(x: 263, y: 6, width: 251, height: 150),
            CGRect(x: 6, y: 162, width: 251, height: 150),
            CGRect(x: 263, y: 162, width: 251, height: 150)
        ])
        #expect(result.contentHeight == 318)
    }

    /// Soft edge leaves less room around the text, and the tiles follow it.
    @Test func softEdgeTilesFollowItsSmallerPadding() {
        let softEdge = NoteCellGeometry.spacing(layout: .twoByTwo, textPadding: CGSize(width: 4, height: 2))
        #expect(softEdge == NoteCellSpacing(margin: CGSize(width: 2, height: 1), gap: CGSize(width: 2, height: 1), padding: CGSize(width: 2, height: 1)))
    }
}
