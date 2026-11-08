import Foundation

/// How long a closed note is kept before Skywrite moves it to the Trash. The choices and their day counts are Safari's
/// "Remove history items" ones (its HistoryAgeInDaysLimit setting uses 1, 7, 14, 31 and 365).
public enum NoteRetention: Int, CaseIterable, Identifiable, Sendable {
    case never = 0
    case oneDay = 1
    case oneWeek = 7
    case twoWeeks = 14
    case oneMonth = 31
    case oneYear = 365

    public var id: Int { rawValue }

    public var days: Int? {
        self == .never ? nil : rawValue
    }

    /// Notes to move to the Trash: closed, not pinned, and untouched for the whole period. The period starts at the later of
    /// the last edit and the moment the note was closed, so a note that sat unedited on screen for weeks still gets the full
    /// period after you close it.
    public func expired(_ records: [NoteRecord], now: Date, modifiedAt: (NoteRecord) -> Date?) -> [NoteRecord] {
        guard let days else { return [] }
        let limit = TimeInterval(days) * 24 * 60 * 60
        return records.filter { record in
            guard record.fileName != nil, !record.isOnScreen, !record.isPinned else { return false }
            let lastEdit = modifiedAt(record) ?? record.createdAt
            let start = max(lastEdit, record.closedAt ?? lastEdit)
            return now.timeIntervalSince(start) >= limit
        }
    }
}
