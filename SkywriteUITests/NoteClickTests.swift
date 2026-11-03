import AppKit
import XCTest

@MainActor
final class NoteClickTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)"]
        app.launch()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testDoubleClickClosesLockedNote() {
        let note = createLockedNote()
        note.doubleClick()
        XCTAssertTrue(note.waitForNonExistence(timeout: 2))
    }

    func testDoubleClickClosesNoteFromAnotherApp() {
        let note = createLockedNote()
        XCUIApplication(bundleIdentifier: "com.apple.finder").activate()
        note.doubleClick()
        XCTAssertTrue(note.waitForNonExistence(timeout: 2))
    }

    func testDoubleClickClosesZoomedNote() {
        let note = createLockedNote()
        let widthBeforeZoom = note.frame.width
        note.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).scroll(byDeltaX: 0, deltaY: 40)
        XCTAssertNotEqual(note.frame.width, widthBeforeZoom, accuracy: 1)
        note.doubleClick()
        XCTAssertTrue(note.waitForNonExistence(timeout: 2))
    }

    func testTwoSlowClicksKeepNoteOpen() {
        let note = createLockedNote()
        note.click()
        waitLongerThanDoubleClick()
        note.click()
        waitLongerThanDoubleClick()
        XCTAssertTrue(note.exists)
    }

    func testDoubleClickWhileEditingKeepsNoteOpen() {
        let note = createLockedNote()
        note.click()
        waitLongerThanDoubleClick()
        note.doubleClick()
        waitLongerThanDoubleClick()
        XCTAssertTrue(note.exists)
    }

    private func createLockedNote() -> XCUIElement {
        app.menuBars.menuBarItems["Skywrite"].click()
        app.menuBars.menuItems["New Note"].click()
        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "value BEGINSWITH 'Click to place'")).firstMatch.waitForExistence(timeout: 2))
        menuBar.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 400, dy: 300)).click()
        let note = app.textViews["note-text"].firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 2))
        app.typeText("Hello Skywrite")
        app.typeKey(.escape, modifierFlags: [])
        return note
    }

    private func waitLongerThanDoubleClick() {
        Thread.sleep(forTimeInterval: NSEvent.doubleClickInterval * 2)
    }
}
