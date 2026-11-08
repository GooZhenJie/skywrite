import Foundation

public enum RecentNotes {
    /// The notes listed under "Recent": unpinned, newest edit first. Pinned notes have their own list.
    public static func pick(_ records: [NoteRecord], modifiedAt: (NoteRecord) -> Date?, limit: Int = NoteMetrics.recentNotesInMenu) -> [NoteRecord] {
        Array(newestFirst(records.filter { !$0.isPinned }, modifiedAt: modifiedAt).prefix(limit))
    }

    /// Every pinned note, newest edit first; pinning is how you keep a note at hand, so the list isn't cut short.
    public static func pinned(_ records: [NoteRecord], modifiedAt: (NoteRecord) -> Date?) -> [NoteRecord] {
        newestFirst(records.filter(\.isPinned), modifiedAt: modifiedAt)
    }

    private static func newestFirst(_ records: [NoteRecord], modifiedAt: (NoteRecord) -> Date?) -> [NoteRecord] {
        let dated = records.filter { $0.fileName != nil }.map { ($0, modifiedAt($0) ?? $0.createdAt) }
        return dated.sorted { $0.1 > $1.1 }.map(\.0)
    }
}
