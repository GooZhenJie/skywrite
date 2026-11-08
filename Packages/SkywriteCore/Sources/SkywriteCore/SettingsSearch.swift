import Foundation

/// Matching for the search field at the top of the settings sidebar, the way System Settings narrows its list as you type.
public enum SettingsSearch {
    /// True when the query is empty, or when any of the names contains it, ignoring case, accents and width (so "dock" finds "Dock").
    public static func matches(_ query: String, names: [String]) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return names.contains { $0.localizedStandardContains(query) }
    }
}
