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
