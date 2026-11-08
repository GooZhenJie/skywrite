import Foundation
import Testing
@testable import SkywriteCore

struct NoteSavingTests {
    private let root: URL
    private let store: NoteStore
    private let utc = TimeZone(identifier: "UTC")!
    private let madeAt = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "SkywriteCoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = NoteStore(notesFolder: root.appending(path: "Notes"), recordURL: root.appending(path: "Support/notes.json"))
    }

    @Test func anEmptyNewNoteGetsNoFile() {
        #expect(store.fileName(forSaving: "", existing: nil, createdAt: madeAt, timeZone: utc) == nil)
        #expect(!FileManager.default.fileExists(atPath: store.notesFolder.path))
    }

    @Test func aNewNoteIsNamedAfterWhenItWasMadeOnceItHasText() throws {
        let fileName = try #require(store.fileName(forSaving: "买牛奶", existing: nil, createdAt: madeAt, timeZone: utc))
        #expect(fileName == "2027-01-15 08.00.00.md")
        try store.writeText("买牛奶", to: fileName)
        #expect(try store.readText(fileName) == "买牛奶")
    }

    @Test func aNoteKeepsItsFileEvenWhenItsTextIsDeleted() {
        #expect(store.fileName(forSaving: "", existing: "a.md", createdAt: madeAt, timeZone: utc) == "a.md")
        #expect(store.fileName(forSaving: "more", existing: "a.md", createdAt: madeAt, timeZone: utc) == "a.md")
    }

    @Test func twoNotesMadeInTheSameSecondGetTheirOwnFiles() throws {
        let first = try #require(store.fileName(forSaving: "one", existing: nil, createdAt: madeAt, timeZone: utc))
        try store.writeText("one", to: first)
        let second = store.fileName(forSaving: "two", existing: nil, createdAt: madeAt, timeZone: utc)
        #expect(second == "2027-01-15 08.00.00 2.md")
    }

    @Test func savingFoldsInTheNotesOnScreenAndKeepsTheOrder() throws {
        let first = NoteRecord(fileName: "a.md", isOnScreen: false, topLeftX: 0, topLeftY: 0, createdAt: madeAt)
        var dragged = NoteRecord(fileName: "b.md", topLeftX: 10, topLeftY: 10, createdAt: madeAt)
        let neverWritten = NoteRecord(topLeftX: 20, topLeftY: 20, createdAt: madeAt)
        let records = [first, dragged, neverWritten]
        dragged.topLeftX = 300
        dragged.zoom = 1.5
        let notInTheList = NoteRecord(fileName: "z.md", topLeftX: 0, topLeftY: 0, createdAt: madeAt)

        let updated = records.updating(with: [dragged, notInTheList])
        try store.saveRecords(updated)

        #expect(updated == [first, dragged, neverWritten])
        #expect(try store.loadRecords() == [first, dragged])
    }
}
