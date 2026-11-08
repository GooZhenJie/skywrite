import CoreGraphics
import Testing
@testable import SkywriteCore

struct ScreenPlacementTests {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    @Test func boxOnUnpluggedScreenIsNotVisible() {
        let box = CGRect(x: 2000, y: 300, width: 200, height: 40)
        #expect(!ScreenPlacement.isVisible(box, on: [screen]))
        #expect(ScreenPlacement.isVisible(box, on: [screen, CGRect(x: 1440, y: 0, width: 1920, height: 1080)]))
    }

    @Test func bringsBoxBackInsideTheEdges() {
        let topLeft = ScreenPlacement.topLeftBringingBack(CGRect(x: 2000, y: 300, width: 200, height: 40), into: screen)
        #expect(topLeft == CGPoint(x: 1440 - NoteMetrics.screenEdgeMargin - 200, y: 340))
    }
}
