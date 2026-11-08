import CoreGraphics
import Testing
@testable import SkywriteCore

struct NoteGeometryTests {
    let start = CGRect(x: 100, y: 200, width: 300, height: 120)
    let minimum = CGSize(width: 60, height: 30)

    @Test func rightEdgeChangesWidthOnly() {
        let size = NoteGeometry.requestedSize(start: start, handle: .right, translation: CGVector(dx: 50, dy: 40), minimumSize: minimum)
        #expect(size == CGSize(width: 350, height: 120))
    }

    @Test func leftEdgeKeepsRightSide() {
        let size = NoteGeometry.requestedSize(start: start, handle: .left, translation: CGVector(dx: -20, dy: 0), minimumSize: minimum)
        let box = NoteGeometry.anchoredBox(start: start, handle: .left, size: size)
        #expect(box.maxX == start.maxX)
        #expect(box.width == 320)
        #expect(box.maxY == start.maxY)
    }

    @Test func topEdgeKeepsBottom() {
        let size = NoteGeometry.requestedSize(start: start, handle: .top, translation: CGVector(dx: 0, dy: 30), minimumSize: minimum)
        let box = NoteGeometry.anchoredBox(start: start, handle: .top, size: size)
        #expect(box.minY == start.minY)
        #expect(box.height == 150)
    }

    @Test func bottomRightCornerKeepsTopLeft() {
        let size = NoteGeometry.requestedSize(start: start, handle: .bottomRight, translation: CGVector(dx: -40, dy: -20), minimumSize: minimum)
        let box = NoteGeometry.anchoredBox(start: start, handle: .bottomRight, size: size)
        #expect(size == CGSize(width: 260, height: 140))
        #expect(box.minX == start.minX)
        #expect(box.maxY == start.maxY)
    }

    @Test func sizeNeverGoesBelowMinimum() {
        let size = NoteGeometry.requestedSize(start: start, handle: .topLeft, translation: CGVector(dx: 1000, dy: -1000), minimumSize: minimum)
        #expect(size == minimum)
    }

    @Test func tallerContentStillKeepsTopFixedWhenDraggingBottom() {
        let box = NoteGeometry.anchoredBox(start: start, handle: .bottom, size: CGSize(width: 300, height: 200))
        #expect(box.maxY == start.maxY)
    }

    @Test func zoomKeepsAnchorFixed() {
        let anchor = CGPoint(x: 150, y: 250)
        let topLeft = CGPoint(x: 100, y: 320)
        let zoomed = NoteGeometry.zoomedPoint(topLeft, around: anchor, factor: 2)
        #expect(zoomed == CGPoint(x: 50, y: 390))
        #expect(NoteGeometry.zoomedPoint(anchor, around: anchor, factor: 3) == anchor)
    }

    @Test func zoomIsClamped() {
        #expect(NoteGeometry.clampedZoom(10) == NoteMetrics.maximumZoom)
        #expect(NoteGeometry.clampedZoom(0.01) == NoteMetrics.minimumZoom)
        #expect(NoteGeometry.clampedZoom(1.5) == 1.5)
    }

    @Test func scrollUpZoomsIn() {
        #expect(NoteGeometry.scrollZoomFactor(deltaY: 10, hasPreciseDeltas: true) > 1)
        #expect(NoteGeometry.scrollZoomFactor(deltaY: -1, hasPreciseDeltas: false) < 1)
    }

    @Test func autoWidthStopsBeforeScreenEdge() {
        #expect(NoteGeometry.autoWidthLimit(boxMinX: 1000, screenMaxX: 1440) == 1440 - 1000 - NoteMetrics.screenEdgeMargin)
        #expect(NoteGeometry.autoWidthLimit(boxMinX: 1430, screenMaxX: 1440) == NoteMetrics.minimumFixedWidth)
    }

    @Test func clickPutsFirstLineOnThePointer() {
        let topLeft = NoteGeometry.placedBox(clickPoint: CGPoint(x: 300, y: 500), lineHeight: 24)
        #expect(topLeft == CGPoint(x: 300, y: 500 + 12 + NoteMetrics.textVerticalPadding))
    }

    @Test func roomierPaddingKeepsTheTextWhereYouClicked() {
        let padding = GlassStyle.liquidGlass.textPadding(zoom: 1)
        let topLeft = NoteGeometry.placedBox(clickPoint: CGPoint(x: 300, y: 500), lineHeight: 24, padding: padding)
        let textStart = CGPoint(x: topLeft.x + padding.width, y: topLeft.y - padding.height)
        #expect(textStart == CGPoint(x: 300 + NoteMetrics.textHorizontalPadding, y: 500 + 12))
    }

    @Test func liquidGlassPaddingMatchesItsCornersAndGrowsWithZoom() {
        #expect(GlassStyle.liquidGlass.textPadding(zoom: 1) == CGSize(width: NoteMetrics.liquidGlassCornerRadius, height: NoteMetrics.liquidGlassCornerRadius))
        #expect(GlassStyle.liquidGlass.textPadding(zoom: 2).width == NoteMetrics.liquidGlassCornerRadius * 2)
        #expect(GlassStyle.softEdge.textPadding(zoom: 2) == CGSize(width: NoteMetrics.textHorizontalPadding, height: NoteMetrics.textVerticalPadding))
    }

    @Test func dragSetsWidthAndHeight() {
        let result = NoteGeometry.draggedBox(from: CGPoint(x: 400, y: 300), to: CGPoint(x: 100, y: 500), lineHeight: 24)
        #expect(result.topLeft == CGPoint(x: 100, y: 500))
        #expect(result.fixedWidth == 300)
        #expect(result.minimumHeight == 200)
    }

    @Test func flatDragSetsWidthOnly() {
        let result = NoteGeometry.draggedBox(from: CGPoint(x: 100, y: 300), to: CGPoint(x: 140, y: 310), lineHeight: 24)
        #expect(result.fixedWidth == NoteMetrics.minimumFixedWidth)
        #expect(result.minimumHeight == nil)
        #expect(NoteGeometry.isDrag(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 3, y: 3)) == false)
    }

    @Test func handleDirections() {
        #expect(ResizeHandle.topLeft.isCorner)
        #expect(!ResizeHandle.left.changesHeight)
        #expect(ResizeHandle.bottom.changesHeight && !ResizeHandle.bottom.changesWidth)
    }
}
