import XCTest

@MainActor
final class SettingsTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    private func launch(appearance: String = "light", openSettings: Bool = true) {
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "--appearance", appearance]
        if openSettings {
            app.launchArguments.append("--open-settings")
        }
        app.launch()
    }

    func testEveryPaneOpens() {
        launch()
        let window = app.windows["settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        for pane in ["General", "Appearance", "Shortcuts", "Storage"] {
            window.outlines.staticTexts[pane].click()
            XCTAssertTrue(window.staticTexts[pane].firstMatch.waitForExistence(timeout: 2))
            attach(window.screenshot(), name: "settings-\(pane)-light")
        }
    }

    func testSidebarSearchNarrowsThePanes() {
        launch()
        let window = app.windows["settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        let search = window.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 2))
        search.click()
        search.typeText("trash")
        XCTAssertTrue(window.outlines.staticTexts["Storage"].waitForExistence(timeout: 2))
        XCTAssertFalse(window.outlines.staticTexts["General"].exists)
        // Typing only narrows the sidebar; the pane you were on stays until you pick a result.
        XCTAssertTrue(window.staticTexts["Show Skywrite In"].exists)
        XCTAssertFalse(window.staticTexts["Closed Notes"].exists)
        attach(window.screenshot(), name: "settings-search-trash")
        window.outlines.staticTexts["Storage"].click()
        XCTAssertTrue(window.staticTexts["Closed Notes"].waitForExistence(timeout: 2))
    }

    func testBackAndForwardButtons() {
        launch()
        let window = app.windows["settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertFalse(window.buttons["Back"].isEnabled)
        window.outlines.staticTexts["Storage"].click()
        XCTAssertTrue(window.staticTexts["Closed Notes"].waitForExistence(timeout: 2))
        window.buttons["Back"].click()
        XCTAssertTrue(window.staticTexts["Show Skywrite In"].waitForExistence(timeout: 2))
        attach(window.screenshot(), name: "settings-back-to-general")
        window.buttons["Forward"].click()
        XCTAssertTrue(window.staticTexts["Closed Notes"].waitForExistence(timeout: 2))
    }

    func testAppearanceScrollsUnderTheToolbar() {
        launch()
        let window = app.windows["settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        window.outlines.staticTexts["Appearance"].click()
        XCTAssertTrue(window.staticTexts["Note Background"].waitForExistence(timeout: 2))
        attach(window.screenshot(), name: "settings-Appearance-top")
        window.buttons["Sea"].click()
        // Scroll the settings, not the sidebar, by scrolling over a section title that's on screen.
        let anchor = window.staticTexts["Note Background"]
        let before = anchor.frame.minY
        anchor.scroll(byDeltaX: 0, deltaY: -160)
        if anchor.frame.minY >= before {
            anchor.scroll(byDeltaX: 0, deltaY: 320)
        }
        XCTAssertLessThan(anchor.frame.minY, before)
        attach(window.screenshot(), name: "settings-Appearance-scrolled-sea")
    }

    func testChineseSettings() {
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(zh-Hans)", "--appearance", "light", "--open-settings"]
        app.launch()
        let window = app.windows["settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(window.staticTexts["显示位置"].waitForExistence(timeout: 2))
        attach(window.screenshot(), name: "settings-General-zh")
        window.outlines.staticTexts["外观"].click()
        attach(window.screenshot(), name: "settings-Appearance-zh")
    }

    func testDarkAppearance() {
        launch(appearance: "dark")
        let window = app.windows["settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        attach(window.screenshot(), name: "settings-General-dark")
        window.outlines.staticTexts["Appearance"].click()
        attach(window.screenshot(), name: "settings-Appearance-dark")
        window.buttons["Ocean"].click()
        attach(window.screenshot(), name: "settings-Appearance-dark-ocean")
        window.outlines.staticTexts["General"].click()
        attach(window.screenshot(), name: "settings-General-dark-ocean")
    }

    func testMenuBarMenuHasTheMainCommands() {
        launch(openSettings: false)
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
        for title in ["New Note", "Hide All Notes", "Reopen Closed Note", "No notes yet", "Open Notes Folder", "Settings…", "Quit Skywrite"] {
            XCTAssertTrue(statusItem.menuItems[title].waitForExistence(timeout: 2), title)
        }
        attach(XCUIScreen.main.screenshot(), name: "status-menu-empty")
        app.typeKey(.escape, modifierFlags: [])
    }

    func testHideAndShowAllNotesFromMenuBar() {
        launch(openSettings: false)
        let note = createNote(text: "Buy milk")
        let statusItem = app.statusItems.firstMatch
        statusItem.click()
        XCTAssertTrue(statusItem.menuItems.matching(NSPredicate(format: "title BEGINSWITH %@", "Buy milk")).firstMatch.waitForExistence(timeout: 2))
        attach(XCUIScreen.main.screenshot(), name: "status-menu-with-note")
        statusItem.menuItems["Hide All Notes"].click()
        XCTAssertTrue(note.waitForNonExistence(timeout: 2))
        statusItem.click()
        statusItem.menuItems["Show All Notes"].click()
        XCTAssertTrue(note.waitForExistence(timeout: 2))
    }

    func testLiquidGlassAndBiggerTextApplyToNotes() {
        launch()
        let window = app.windows["settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        let note = createNote(text: "Buy milk")
        let heightBefore = note.frame.height
        window.outlines.staticTexts["Appearance"].click()
        window.buttons["Liquid Glass"].click()
        for _ in 0..<10 {
            app.menuBars.menuBarItems["View"].click()
            app.menuBars.menuBarItems["View"].menuItems["Bigger Text"].click()
        }
        XCTAssertGreaterThan(note.frame.height, heightBefore)
        attach(XCUIScreen.main.screenshot(), name: "note-liquid-glass-30pt")
    }

    func testPinnedNoteGetsItsOwnSectionInTheMenuBar() {
        launch(openSettings: false)
        let note = createNote(text: "Buy milk")
        note.rightClick()
        app.menuItems["Pin Note"].click()
        let statusItem = app.statusItems.firstMatch
        statusItem.click()
        XCTAssertTrue(statusItem.menuItems["Pinned"].waitForExistence(timeout: 2))
        attach(XCUIScreen.main.screenshot(), name: "status-menu-with-pinned-note")
        statusItem.typeKey(.escape, modifierFlags: [])
        note.rightClick()
        XCTAssertTrue(app.menuItems["Unpin Note"].waitForExistence(timeout: 2))
        app.typeKey(.escape, modifierFlags: [])
    }

    private func createNote(text: String) -> XCUIElement {
        let statusItem = app.statusItems.firstMatch
        statusItem.click()
        statusItem.menuItems["New Note"].click()
        let hint = app.staticTexts.matching(NSPredicate(format: "value BEGINSWITH %@", "Click to place")).firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: 3))
        app.menuBars.firstMatch.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 400, dy: 300)).click()
        let note = app.textViews["note-text"]
        XCTAssertTrue(note.waitForExistence(timeout: 3))
        note.typeText(text)
        note.typeKey(.escape, modifierFlags: [])
        return note
    }

    private func attach(_ screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
