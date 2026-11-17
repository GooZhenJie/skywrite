import Foundation

/// How long ago a note was edited, the same short way in the menu bar menu and the quick panel: "now", "5 min ago",
/// "yesterday".
enum RelativeTime {
    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.dateTimeStyle = .named
        return formatter
    }()

    /// A date after `now` (a clock that moved back) reads as "now".
    static func text(for date: Date, now: Date = Date()) -> String {
        formatter.localizedString(for: min(date, now), relativeTo: now)
    }
}
