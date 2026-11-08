import Foundation
import Testing
@testable import SkywriteCore

struct NoteRetentionTests {
    private let now = Date(timeIntervalSince1970: 1_000_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    private func closedNote(_ fileName: String, editedDaysAgo: Double, closedDaysAgo: Double? = nil, pinned: Bool = false) -> (NoteRecord, Date) {
        let record = NoteRecord(
            fileName: fileName,
            isOnScreen: false,
            topLeftX: 0,
            topLeftY: 0,
            createdAt: now.addingTimeInterval(-400 * day),
            isPinned: pinned,
            closedAt: closedDaysAgo.map { now.addingTimeInterval(-$0 * day) }
        )
        return (record, now.addingTimeInterval(-editedDaysAgo * day))
    }

    private func expired(_ notes: [(NoteRecord, Date)], _ retention: NoteRetention) -> [String?] {
        let edits = Dictionary(uniqueKeysWithValues: notes.map { ($0.0.id, $0.1) })
        return retention.expired(notes.map(\.0), now: now, modifiedAt: { edits[$0.id] }).map(\.fileName)
    }

    @Test func neverMovesNothing() {
        #expect(expired([closedNote("old.md", editedDaysAgo: 999)], .never).isEmpty)
    }

    @Test func movesClosedNotesUntouchedForThePeriod() {
        let notes = [closedNote("old.md", editedDaysAgo: 8), closedNote("fresh.md", editedDaysAgo: 6)]
        #expect(expired(notes, .oneWeek) == ["old.md"])
    }

    @Test func periodStartsWhenTheNoteWasClosedIfThatIsLater() {
        let notes = [closedNote("left-on-screen.md", editedDaysAgo: 30, closedDaysAgo: 2), closedNote("closed-long-ago.md", editedDaysAgo: 30, closedDaysAgo: 20)]
        #expect(expired(notes, .twoWeeks) == ["closed-long-ago.md"])
    }

    @Test func notesClosedByOlderVersionsCountFromTheLastEdit() {
        #expect(expired([closedNote("legacy.md", editedDaysAgo: 2)], .oneDay) == ["legacy.md"])
    }

    @Test func pinnedNotesAreNeverMoved() {
        #expect(expired([closedNote("pinned.md", editedDaysAgo: 999, pinned: true)], .oneDay).isEmpty)
    }

    @Test func notesOnScreenAreNeverMoved() {
        var (record, edited) = closedNote("on-screen.md", editedDaysAgo: 999)
        record.isOnScreen = true
        #expect(expired([(record, edited)], .oneDay).isEmpty)
    }

    @Test func exactlyThePeriodCounts() {
        #expect(expired([closedNote("edge.md", editedDaysAgo: 31)], .oneMonth) == ["edge.md"])
    }

    @Test func choicesMatchSafari() {
        #expect(NoteRetention.allCases.map(\.days) == [nil, 1, 7, 14, 31, 365])
    }
}
