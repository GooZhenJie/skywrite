import Foundation
import Testing
@testable import SkywriteCore

struct RecentNotesTests {
    @Test func newestModifiedFirstAndLimited() {
        let old = NoteRecord(fileName: "old.md", topLeftX: 0, topLeftY: 0, createdAt: Date(timeIntervalSince1970: 100))
        let edited = NoteRecord(fileName: "edited.md", topLeftX: 0, topLeftY: 0, createdAt: Date(timeIntervalSince1970: 50))
        let unsaved = NoteRecord(topLeftX: 0, topLeftY: 0, createdAt: Date(timeIntervalSince1970: 999))
        let modified = ["edited.md": Date(timeIntervalSince1970: 500)]
        let picked = RecentNotes.pick([old, edited, unsaved], modifiedAt: { $0.fileName.flatMap { modified[$0] } }, limit: 1)
        #expect(picked.map(\.fileName) == ["edited.md"])
    }

    @Test func pinnedNotesLeaveRecentAndAreAllListedNewestFirst() {
        let pinnedOld = NoteRecord(fileName: "pinned-old.md", topLeftX: 0, topLeftY: 0, createdAt: Date(timeIntervalSince1970: 100), isPinned: true)
        let pinnedNew = NoteRecord(fileName: "pinned-new.md", topLeftX: 0, topLeftY: 0, createdAt: Date(timeIntervalSince1970: 300), isPinned: true)
        let plain = NoteRecord(fileName: "plain.md", topLeftX: 0, topLeftY: 0, createdAt: Date(timeIntervalSince1970: 200))
        let records = [pinnedOld, plain, pinnedNew]
        #expect(RecentNotes.pick(records, modifiedAt: { _ in nil }, limit: 6).map(\.fileName) == ["plain.md"])
        #expect(RecentNotes.pinned(records, modifiedAt: { _ in nil }).map(\.fileName) == ["pinned-new.md", "pinned-old.md"])
    }
}
