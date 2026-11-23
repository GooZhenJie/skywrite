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

    // Two screens: a 1920 × 1080 display, and a smaller built-in one to its left whose bottom
    // edge sits 248 pt higher, leaving a gap below it. Visible frames leave out the menu bar and the Dock.
    let external = CGRect(x: 0, y: 77, width: 1920, height: 973)
    let builtIn = CGRect(x: -1280, y: 248, width: 1280, height: 804)
    var areas: [CGRect] {
        [external, builtIn]
    }

    @Test func leavesABoxThatShowsEnoughAlone() {
        let box = CGRect(x: -600, y: 900, width: 700, height: 400)
        #expect(ScreenPlacement.keepingVisible(box, in: areas) == box)
    }

    @Test func pullsABoxUnderTheMenuBarDownUntilAStripShowsBelowIt() {
        let box = CGRect(x: -900, y: 1030, width: 700, height: 300)
        let kept = ScreenPlacement.keepingVisible(box, in: areas)
        #expect(kept == CGRect(x: -900, y: 1052 - 50, width: 700, height: 300))
    }

    @Test func pullsABoxPastTheLeftEdgeBackUntilItsWidthShows() {
        let box = CGRect(x: -2000, y: 500, width: 700, height: 300)
        let kept = ScreenPlacement.keepingVisible(box, in: areas)
        #expect(kept.origin == CGPoint(x: -1280 - 700 + 50, y: 500))
    }

    @Test func pullsABoxPastTheBottomUpUntilOneLineShows() {
        let box = CGRect(x: 400, y: -500, width: 700, height: 300)
        let kept = ScreenPlacement.keepingVisible(box, in: areas)
        #expect(kept.origin == CGPoint(x: 400, y: 77 - 300 + 50))
    }

    @Test func movesABoxInTheGapBelowTheSmallerScreenOntoTheNearestOne() {
        let box = CGRect(x: -700, y: -100, width: 300, height: 200)
        let kept = ScreenPlacement.keepingVisible(box, in: areas)
        #expect(kept.origin == CGPoint(x: -700, y: 248 - 200 + 50))
    }

    @Test func keepsAllOfABoxSmallerThanTheMinimumInSight() {
        let box = CGRect(x: -1300, y: 600, width: 20, height: 16)
        let kept = ScreenPlacement.keepingVisible(box, in: areas)
        #expect(kept.origin == CGPoint(x: -1280, y: 600))
    }
}
