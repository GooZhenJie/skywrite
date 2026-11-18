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

    /// A note 718 × 186 at 1×, on a 1920-wide screen whose free area is 973 tall. Its width
    /// reaches the screen's at 1920 / 718 ≈ 2.67×, well before the 5× limit it used to get to.
    @Test func zoomingInStopsWhenTheNoteFillsItsScreen() {
        let box = CGSize(width: 718, height: 186)
        let screen = CGSize(width: 1920, height: 973)
        #expect(NoteGeometry.zoomFitting(5, currentZoom: 1, box: box, in: screen) == 1920.0 / 718.0)
        #expect(NoteGeometry.zoomFitting(2, currentZoom: 1, box: box, in: screen) == 2)
        // A tall note stops at the screen's height.
        #expect(NoteGeometry.zoomFitting(5, currentZoom: 1, box: CGSize(width: 300, height: 600), in: screen) == 973.0 / 600.0)
    }

    @Test func zoomingOutIsNeverHeldBack() {
        let box = CGSize(width: 3590, height: 893)
        #expect(NoteGeometry.zoomFitting(4, currentZoom: 5, box: box, in: CGSize(width: 1920, height: 973)) == 4)
    }

    @Test func aNoteAlreadyBiggerThanItsScreenNeitherGrowsNorShrinks() {
        let box = CGSize(width: 3590, height: 893)
        #expect(NoteGeometry.zoomFitting(4.5, currentZoom: 4, box: box, in: CGSize(width: 1920, height: 973)) == 4)
    }

    @Test func aNoteIsMovedBackInsideItsScreen() {
        let screen = CGRect(x: 0, y: 77, width: 1920, height: 973)
        let inside = CGRect(x: 100, y: 300, width: 500, height: 200)
        #expect(NoteGeometry.moved(inside, inside: screen) == inside)
        // Past the right and top edges: pulled left and down.
        #expect(NoteGeometry.moved(CGRect(x: 1600, y: 900, width: 500, height: 200), inside: screen) == CGRect(x: 1420, y: 850, width: 500, height: 200))
        // Past the left and bottom edges, onto the display on the left: pushed right and up.
        #expect(NoteGeometry.moved(CGRect(x: -300, y: 20, width: 500, height: 200), inside: screen) == CGRect(x: 0, y: 77, width: 500, height: 200))
        // Bigger than the screen: the top-left corner lines up with the screen's.
        #expect(NoteGeometry.moved(CGRect(x: -266, y: 144, width: 3590, height: 1200), inside: screen) == CGRect(x: 0, y: 1050 - 1200, width: 3590, height: 1200))
    }

    @Test func scrollUpZoomsIn() {
        #expect(NoteGeometry.scrollZoomFactor(deltaY: 10, hasPreciseDeltas: true) > 1)
        #expect(NoteGeometry.scrollZoomFactor(deltaY: -1, hasPreciseDeltas: false) < 1)
    }

    @Test func autoWidthStopsBeforeScreenEdge() {
        #expect(NoteGeometry.autoWidthLimit(boxMinX: 1000, screenMaxX: 1440) == 1440 - 1000 - NoteMetrics.screenEdgeMargin)
        #expect(NoteGeometry.autoWidthLimit(boxMinX: 1430, screenMaxX: 1440) == NoteMetrics.minimumFixedWidth)
    }

    @Test func lockingKeepsTheWidthTheNoteHasNow() {
        #expect(NoteGeometry.widthAfterLocking(fixedWidth: nil, boxWidth: 300, zoom: 1.5) == 200)
        #expect(NoteGeometry.widthAfterLocking(fixedWidth: 120, boxWidth: 300, zoom: 1.5) == 120)
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
