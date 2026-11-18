import Foundation

/// Bulleted, numbered and task lists, written the Markdown way and shown the way Notion shows them.
///
/// A bullet is `-`, `*` or `+` and a space at the very start of a line; a numbered item is a number, `.` or `)`, and a
/// space, the shortcuts Notion's help lists (it also takes `a.` and `i.`, which aren't Markdown). A task is a bullet
/// followed by `[ ]`, or `[x]` once it's ticked, and a space: GitHub's task list, which Obsidian reads too. Lines below
/// an item that start with as many spaces as its marker is long continue that item, the way Markdown writes a line
/// break inside one. Nesting isn't supported, so an indented `- ` is just text.
extension NoteMarkdown {
    private enum Marker {
        case bullet(Character)
        case numbered(Int, Character)
        case task(Character, isChecked: Bool)
    }

    /// Every list item in `text`, top to bottom.
    public static func listItems(in text: String) -> [NoteListItem] {
        let lines = lineRanges(in: text as NSString)
        var items: [NoteListItem] = []
        /// The number and delimiter of the numbered item just before, while a numbered list is going on.
        var previous: (number: Int, delimiter: Character)?
        var index = 0
        while index < lines.count {
            let line = lines[index]
            guard let (marker, markerLength) = marker(in: line.text) else {
                previous = nil
                index += 1
                continue
            }
            let indent = String(repeating: " ", count: markerLength)
            var next = index + 1
            while next < lines.count, lines[next].text.hasPrefix(indent) {
                next += 1
            }
            let markerRange = NSRange(location: line.range.location, length: markerLength)
            let continuations = lines[(index + 1)..<next].map(\.range)
            switch marker {
            case .bullet(let symbol):
                previous = nil
                items.append(NoteListItem(kind: .bullet, label: "•", lineRange: line.range, markerRange: markerRange, nextMarker: "\(symbol) ", continuationLines: continuations))
            case let .numbered(typed, delimiter):
                let number = previous.flatMap { $0.delimiter == delimiter ? $0.number + 1 : nil } ?? typed
                previous = (number, delimiter)
                items.append(NoteListItem(kind: .numbered, label: "\(number)\(delimiter)", lineRange: line.range, markerRange: markerRange, nextMarker: "\(number + 1)\(delimiter) ", continuationLines: continuations))
            case let .task(symbol, isChecked):
                previous = nil
                // Return always starts an unticked box, the way Notion's next to-do starts empty.
                items.append(NoteListItem(kind: .task(isChecked: isChecked), label: "", lineRange: line.range, markerRange: markerRange, nextMarker: "\(symbol) [ ] ", continuationLines: continuations))
            }
            index = next
        }
        return items
    }

    /// What typing a space turns the start of a line into, given the text between the line's start and the caret: `[]`
    /// becomes an unticked task, Notion's shortcut, and so does `【】`, which is what `[]` comes out as while typing
    /// with Chinese punctuation. Typed at the start of a bulleted item, it keeps the item's
    /// bullet; at the start of a numbered item, the item turns into a task. Nil for anything else, so the space is
    /// typed as usual.
    public static func taskMarker(replacing typed: String) -> String? {
        let found = marker(in: typed)
        let rest = typed.dropFirst(found?.length ?? 0)
        guard rest == "[]" || rest == "【】" else { return nil }
        switch found?.marker {
        case .bullet(let symbol)?:
            return "\(symbol) [ ] "
        case .task?:
            return nil
        case .numbered?, nil:
            return "- [ ] "
        }
    }

    private static func lineRanges(in string: NSString) -> [(range: NSRange, text: String)] {
        var lines: [(range: NSRange, text: String)] = []
        var location = 0
        while location < string.length {
            var lineEnd = 0
            var contentsEnd = 0
            string.getLineStart(nil, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: location, length: 0))
            let range = NSRange(location: location, length: contentsEnd - location)
            lines.append((range, string.substring(with: range)))
            location = lineEnd
        }
        return lines
    }

    /// The marker a line starts with, and how long it is with its space, in UTF-16 units (all its characters are ASCII).
    private static func marker(in line: String) -> (marker: Marker, length: Int)? {
        let characters = Array(line.prefix(12))
        if characters.count >= 2, let symbol = characters.first, "-*+".contains(symbol), characters[1] == " " {
            // GitHub's task list takes a space, `x` or `X` between the brackets, and a space after them.
            if characters.count >= 6, characters[2] == "[", " xX".contains(characters[3]), characters[4] == "]", characters[5] == " " {
                return (.task(symbol, isChecked: characters[3] != " "), 6)
            }
            return (.bullet(symbol), 2)
        }
        let digits = characters.prefix { $0.isASCII && $0.isNumber }
        guard (1...9).contains(digits.count), let number = Int(String(digits)), characters.count >= digits.count + 2 else { return nil }
        let delimiter = characters[digits.count]
        guard delimiter == "." || delimiter == ")", characters[digits.count + 1] == " " else { return nil }
        return (.numbered(number, delimiter), digits.count + 2)
    }
}

/// A line of a bulleted, numbered or task list, and the lines continuing it; see `NoteMarkdown.listItems(in:)`.
public struct NoteListItem: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case bullet
        case numbered
        case task(isChecked: Bool)
    }

    public let kind: Kind
    /// What stands in front of the item: "•" for a bullet. A numbered item shows its place in the list counted from
    /// the first item's number, whatever number was typed, the way Notion numbers a list itself ("3."). A task has
    /// none: the note draws its box.
    public let label: String
    /// The item's first line, without its line break, in UTF-16 units the way `NSString` counts.
    public let lineRange: NSRange
    /// The marker and the space after it, such as "- " or "12. ", which the note never shows as text.
    public let markerRange: NSRange
    /// What Return starts the next item with: the same bullet, or the next number.
    public let nextMarker: String
    /// Every line that continues the item, without line breaks.
    public let continuationLines: [NSRange]

    /// Where the item's text starts.
    public var contentStart: Int {
        NSMaxRange(markerRange)
    }

    /// The spaces at the start of each continuing line, which the note hides so the text lines up with the item's.
    public var continuationIndents: [NSRange] {
        continuationLines.map { NSRange(location: $0.location, length: markerRange.length) }
    }

    /// The marker and the indents: text the caret never stops inside.
    public var hiddenRanges: [NSRange] {
        [markerRange] + continuationIndents
    }

    /// From the start of the item's text to the end of its last line.
    public var textRange: NSRange {
        let end = continuationLines.last.map(NSMaxRange) ?? NSMaxRange(lineRange)
        return NSRange(location: contentStart, length: end - contentStart)
    }

    /// Nothing typed after the marker yet.
    public var isEmpty: Bool {
        contentStart == NSMaxRange(lineRange) && continuationLines.isEmpty
    }

    /// A task that's been ticked.
    public var isChecked: Bool {
        kind == .task(isChecked: true)
    }

    /// For a task, the character between its brackets: a space, or `x` once it's ticked. Nil for other items.
    public var checkMarkRange: NSRange? {
        guard case .task = kind else { return nil }
        return NSRange(location: markerRange.location + 3, length: 1)
    }

    /// The text you can see on each of the item's lines: the first line after its marker, the others after their indent.
    public var visibleTextRanges: [NSRange] {
        let first = NSRange(location: contentStart, length: NSMaxRange(lineRange) - contentStart)
        return [first] + continuationLines.map { NSRange(location: $0.location + markerRange.length, length: $0.length - markerRange.length) }
    }
}
