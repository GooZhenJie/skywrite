import Foundation

/// A note as the quick panel lists it: the note as it shows on screen and what the list shows next to it.
public struct SearchableNote: Equatable, Identifiable, Sendable {
    public var id: UUID
    /// The note as it shows on screen, which the preview draws; see `NoteDisplay`.
    public let display: NoteDisplay
    /// What the search looks through: the text the note shows, without the file's Markdown marks or cell comments.
    public let text: String
    /// The first line with text in it, the same title the menus show, not shortened; the file's name when there's none,
    /// the way the menu bar menu does.
    public let title: String
    public var fileName: String
    public var modifiedAt: Date
    public var createdAt: Date
    public var isOnScreen: Bool
    public var isPinned: Bool

    /// `fileText` is what's saved in the note's file.
    public init(id: UUID, fileText: String, fileName: String, modifiedAt: Date, createdAt: Date, isOnScreen: Bool, isPinned: Bool) {
        self.id = id
        display = NoteDisplay(fileText: fileText)
        text = display.text
        title = display.title.isEmpty ? fileName : display.title
        self.fileName = fileName
        self.modifiedAt = modifiedAt
        self.createdAt = createdAt
        self.isOnScreen = isOnScreen
        self.isPinned = isPinned
    }
}

/// The three filters at the top of the quick panel.
public enum NoteFilter: String, CaseIterable, Sendable {
    case all
    case onScreen
    case pinned

    public func includes(_ note: SearchableNote) -> Bool {
        switch self {
        case .all: true
        case .onScreen: note.isOnScreen
        case .pinned: note.isPinned
        }
    }
}

/// One row of the quick panel's list, with the stretches of text that matched the search marked.
public struct NoteMatch: Equatable, Identifiable, Sendable {
    public var note: SearchableNote
    public var title: String
    public var titleMatches: [Range<String.Index>]
    /// When the search matched below the first line: the line it matched, cut at the front so the match shows.
    public var excerpt: String?
    public var excerptMatches: [Range<String.Index>]

    public var id: UUID { note.id }
}

public struct NoteSection: Equatable, Sendable {
    public enum Kind: Hashable, Sendable {
        case pinned
        case today
        case earlier
        /// While searching the list isn't grouped.
        case results
    }

    public var kind: Kind
    public var matches: [NoteMatch]
}

public enum NoteSearch {
    /// Characters kept in front of a match when an excerpt is cut, so the match keeps a little of what came before it.
    /// A placeholder picked for the mock-up, not measured.
    public static let excerptLeadingCharacters = 8
    /// A line whose match starts within this many characters is shown whole. The list row leaves about 190 pt for the line
    /// next to the edit time, roughly 16 Chinese or 29 Latin characters at 12 pt (estimated from the font size, not measured).
    public static let excerptShownWholeWithin = 12

    private static let compareOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]

    /// The words to look for: a search for "牛奶 milk" finds notes that have both, anywhere in them.
    public static func terms(in query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// The list the quick panel shows. With nothing typed: pinned notes, then notes edited today, then the rest, newest edit
    /// first in each. While searching: every note that has all the words, those with a word in the title first.
    public static func sections(for notes: [SearchableNote], query: String, filter: NoteFilter, now: Date, calendar: Calendar = .current) -> [NoteSection] {
        let shown = notes.filter(filter.includes).sorted { $0.modifiedAt > $1.modifiedAt }
        let terms = terms(in: query)
        guard !terms.isEmpty else {
            let pinned = shown.filter(\.isPinned)
            let rest = shown.filter { !$0.isPinned }
            let today = rest.filter { calendar.isDate($0.modifiedAt, inSameDayAs: now) }
            let earlier = rest.filter { !calendar.isDate($0.modifiedAt, inSameDayAs: now) }
            return [NoteSection(kind: .pinned, matches: pinned.map(unmarked)),
                    NoteSection(kind: .today, matches: today.map(unmarked)),
                    NoteSection(kind: .earlier, matches: earlier.map(unmarked))]
                .filter { !$0.matches.isEmpty }
        }
        let found = shown.compactMap { match($0, terms: terms) }
        let titled = found.filter { !$0.titleMatches.isEmpty }
        let untitled = found.filter(\.titleMatches.isEmpty)
        let results = titled + untitled
        return results.isEmpty ? [] : [NoteSection(kind: .results, matches: results)]
    }

    /// The note marked up for the list, or nil when it doesn't have every word.
    public static func match(_ note: SearchableNote, terms: [String]) -> NoteMatch? {
        guard terms.allSatisfy({ note.text.range(of: $0, options: compareOptions) != nil || note.title.range(of: $0, options: compareOptions) != nil }) else { return nil }
        let title = note.title
        let titleMatches = ranges(of: terms, in: title)
        let missing = terms.filter { title.range(of: $0, options: compareOptions) == nil }
        guard !missing.isEmpty, let line = linesBelowTitle(note.text).first(where: { line in missing.contains { line.range(of: $0, options: compareOptions) != nil } }) else {
            return NoteMatch(note: note, title: title, titleMatches: titleMatches, excerpt: nil, excerptMatches: [])
        }
        let excerpt = shortened(line, toShow: missing)
        return NoteMatch(note: note, title: title, titleMatches: titleMatches, excerpt: excerpt, excerptMatches: ranges(of: terms, in: excerpt))
    }

    private static func unmarked(_ note: SearchableNote) -> NoteMatch {
        NoteMatch(note: note, title: note.title, titleMatches: [], excerpt: nil, excerptMatches: [])
    }

    /// Every line after the title line, trimmed, skipping empty ones.
    private static func linesBelowTitle(_ text: String) -> [String] {
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return Array(lines.dropFirst())
    }

    /// The line from a little before the first match on, with "…" in front when the start was cut off. Short lines stay whole.
    private static func shortened(_ line: String, toShow terms: [String]) -> String {
        let first = terms.compactMap { line.range(of: $0, options: compareOptions)?.lowerBound }.min() ?? line.startIndex
        guard line.distance(from: line.startIndex, to: first) > excerptShownWholeWithin else { return line }
        let start = line.index(first, offsetBy: -excerptLeadingCharacters)
        return "…" + line[start...].trimmingCharacters(in: .whitespaces)
    }

    /// Every place any of the words appears, in order, for bolding in the list and marking in the preview.
    public static func ranges(of terms: [String], in text: String) -> [Range<String.Index>] {
        var found: [Range<String.Index>] = []
        for term in terms where !term.isEmpty {
            var searchStart = text.startIndex
            while searchStart < text.endIndex, let range = text.range(of: term, options: compareOptions, range: searchStart..<text.endIndex) {
                found.append(range)
                searchStart = range.upperBound
            }
        }
        return found.sorted { $0.lowerBound < $1.lowerBound }
    }
}
