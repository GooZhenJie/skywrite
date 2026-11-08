import Foundation
import Testing
@testable import SkywriteCore

struct NoteStoreTests {
    let root: URL
    let store: NoteStore

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("SkywriteCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = NoteStore(notesFolder: root.appendingPathComponent("Notes"), recordURL: root.appendingPathComponent("Support/notes.json"))
    }

    @Test func missingRecordFileLoadsEmpty() throws {
        #expect(try store.loadRecords().isEmpty)
    }

    @Test func recordsRoundTrip() throws {
        let record = NoteRecord(fileName: "a.md", topLeftX: 10, topLeftY: 20, fixedWidth: 300, minimumHeight: 90, zoom: 1.5, createdAt: Date(timeIntervalSince1970: 1_800_000_000))
        let closed = NoteRecord(fileName: "b.md", isOnScreen: false, topLeftX: 1, topLeftY: 2, createdAt: Date(timeIntervalSince1970: 1_800_000_000))
        try store.saveRecords([record, closed])
        #expect(try store.loadRecords() == [record, closed])
    }

    @Test func pinAndClosingTimeRoundTrip() throws {
        let record = NoteRecord(fileName: "a.md", isOnScreen: false, topLeftX: 0, topLeftY: 0, createdAt: Date(timeIntervalSince1970: 1_800_000_000), isPinned: true, closedAt: Date(timeIntervalSince1970: 1_800_000_500))
        try store.saveRecords([record])
        #expect(try store.loadRecords() == [record])
    }

    @Test func recordsFromBeforePinningLoadUnpinned() throws {
        let legacy = """
        {"version": 1, "notes": [{"createdAt": "2026-11-01T08:00:00Z", "fileName": "old.md", "id": "6B1E2B0C-3C47-4F5B-9B5E-1E0C2D3A4B5C", "isOnScreen": false, "topLeftX": 10, "topLeftY": 20, "zoom": 1}]}
        """
        try FileManager.default.createDirectory(at: store.recordURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(legacy.utf8).write(to: store.recordURL)
        let records = try store.loadRecords()
        #expect(records.count == 1)
        #expect(records.first?.isPinned == false)
        #expect(records.first?.closedAt == nil)
        #expect(records.first?.fileName == "old.md")
    }

    @Test func recordsWithoutFilesAreNotSaved() throws {
        try store.saveRecords([NoteRecord(topLeftX: 0, topLeftY: 0)])
        #expect(try store.loadRecords().isEmpty)
    }

    @Test func textRoundTripCreatesFolder() throws {
        try store.writeText("买牛奶\n三点回电话", to: "x.md")
        #expect(try store.readText("x.md") == "买牛奶\n三点回电话")
    }

    @Test func fileNameUsesCreationTimeAndAvoidsClashes() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let utc = TimeZone(identifier: "UTC")!
        let first = store.makeFileName(createdAt: date, timeZone: utc)
        #expect(first == "2027-01-15 08.00.00.md")
        try store.writeText("one", to: first)
        #expect(store.makeFileName(createdAt: date, timeZone: utc) == "2027-01-15 08.00.00 2.md")
    }

    @Test func trashingMissingFileDoesNothing() throws {
        try store.moveToTrash("never-existed.md")
        #expect(!store.fileExists("never-existed.md"))
    }
}

struct NoteStoreMoveTests {
    @Test func movesNotesAndRenamesClashes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SkywriteCoreTests-\(UUID().uuidString)", isDirectory: true)
        let store = NoteStore(notesFolder: root.appendingPathComponent("Old"), recordURL: root.appendingPathComponent("notes.json"))
        let newFolder = root.appendingPathComponent("New")
        try store.writeText("one", to: "a.md")
        try store.writeText("two", to: "b.md")
        try NoteStore(notesFolder: newFolder, recordURL: store.recordURL).writeText("already here", to: "b.md")
        let result = try store.movingNotes(["a.md", "b.md", "gone.md"], to: newFolder)
        #expect(result.renamed == ["b.md": "b 2.md"])
        #expect(try result.store.readText("a.md") == "one")
        #expect(try result.store.readText("b 2.md") == "two")
        #expect(try result.store.readText("b.md") == "already here")
        #expect(!store.fileExists("a.md"))
    }
}
