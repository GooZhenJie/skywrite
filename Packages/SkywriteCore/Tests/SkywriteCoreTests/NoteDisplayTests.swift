import Testing
@testable import SkywriteCore

struct NoteDisplayTests {
    @Test func marksTheNoteHidesAreLeftOut() {
        let display = NoteDisplay(fileText: "## Shopping\n- milk\n- [x] eggs\n3. bread\n1. jam\n#tag stays")
        #expect(display.layout == .single)
        #expect(display.cells == [[
            .init(kind: .heading(level: 2), text: "Shopping"),
            .init(kind: .bullet, text: "milk"),
            .init(kind: .task(isChecked: true), text: "eggs"),
            .init(kind: .numbered(label: "3."), text: "bread"),
            .init(kind: .numbered(label: "4."), text: "jam"),
            .init(kind: .text, text: "#tag stays")
        ]])
        #expect(display.text == "Shopping\nmilk\neggs\n3. bread\n4. jam\n#tag stays")
        #expect(display.title == "Shopping")
    }

    @Test func linesContinuingAnItemJoinIt() {
        let display = NoteDisplay(fileText: "- first\n  second line\nafter\n\n1. one\n   more\n")
        #expect(display.cells == [[
            .init(kind: .bullet, text: "first\nsecond line"),
            .init(kind: .text, text: "after"),
            .init(kind: .text, text: ""),
            .init(kind: .numbered(label: "1."), text: "one\nmore")
        ]])
    }

    @Test func emptyItemsKeepTheirMarker() {
        let display = NoteDisplay(fileText: "- \n- [ ] ")
        #expect(display.cells == [[.init(kind: .bullet, text: ""), .init(kind: .task(isChecked: false), text: "")]])
        #expect(display.title == "")
    }

    @Test func noteWithCellsIsReadCellByCell() {
        let file = NoteDocument(layout: .twoByTwo, cells: ["## P0\n- [ ] ship the fix", "P1", "", "x"]).text
        let display = NoteDisplay(fileText: file)
        #expect(display.layout == .twoByTwo)
        #expect(display.cells.count == 4)
        #expect(display.cells[2].isEmpty)
        #expect(display.text == "P0\nship the fix\nP1\nx")
        #expect(display.title == "P0")
    }
}
