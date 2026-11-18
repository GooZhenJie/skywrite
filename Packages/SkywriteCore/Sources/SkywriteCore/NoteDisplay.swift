import Foundation

/// A note the way it shows on screen, for the places that show or search it outside the note itself: its title in the
/// menus, and the quick panel's list, search and preview. The Markdown marks the note hides are left out (a heading's
/// `#`, a list item's `- `, `1. ` or `- [ ] `), and a note with cells is read cell by cell rather than as its file, so
/// the layout line and the comments between cells never show: the quick panel shows and searches what the note shows,
/// not the file's Markdown.
public struct NoteDisplay: Equatable, Sendable {
    public let layout: NoteLayout
    /// Each cell's blocks, top to bottom; cells in reading order. A plain note has one cell.
    public let cells: [[NoteDisplayBlock]]

    /// `fileText` is what's saved in the note's file.
    public init(fileText: String) {
        let document = NoteDocument.parse(fileText)
        layout = document.layout
        cells = document.cells.map(Self.blocks(in:))
    }

    /// Every cell's text one after another, a block to a line: what the quick panel searches.
    public var text: String {
        cells.joined().map(\.plainText).joined(separator: "\n")
    }

    /// The first line with something in it, without spaces around it: the note's title in the menus and the quick panel.
    public var title: String {
        text.split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
    }

    /// The blocks of one cell's text, read with the same rules the note draws it with (`NoteMarkdown.headings(in:)` and
    /// `NoteMarkdown.listItems(in:)`).
    static func blocks(in cell: String) -> [NoteDisplayBlock] {
        let string = cell as NSString
        let items = Dictionary(NoteMarkdown.listItems(in: cell).map { ($0.lineRange.location, $0) }) { first, _ in first }
        let headings = Dictionary(NoteMarkdown.headings(in: cell).map { ($0.lineRange.location, $0) }) { first, _ in first }
        var blocks: [NoteDisplayBlock] = []
        var location = 0
        while location < string.length {
            var lineEnd = 0
            var contentsEnd = 0
            string.getLineStart(nil, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: location, length: 0))
            if let item = items[location] {
                let text = item.visibleTextRanges.map { string.substring(with: $0) }.joined(separator: "\n")
                blocks.append(NoteDisplayBlock(kind: kind(of: item), text: text))
                let lastLine = item.continuationLines.last ?? item.lineRange
                var itemEnd = 0
                string.getLineStart(nil, end: &itemEnd, contentsEnd: nil, for: NSRange(location: NSMaxRange(lastLine), length: 0))
                location = max(itemEnd, lineEnd)
                continue
            }
            if let heading = headings[location] {
                let start = NSMaxRange(heading.markerRange)
                blocks.append(NoteDisplayBlock(kind: .heading(level: heading.level), text: string.substring(with: NSRange(location: start, length: contentsEnd - start))))
            } else {
                blocks.append(NoteDisplayBlock(kind: .text, text: string.substring(with: NSRange(location: location, length: contentsEnd - location))))
            }
            location = lineEnd
        }
        return blocks
    }

    private static func kind(of item: NoteListItem) -> NoteDisplayBlock.Kind {
        switch item.kind {
        case .bullet:
            .bullet
        case .numbered:
            .numbered(label: item.label)
        case .task(let isChecked):
            .task(isChecked: isChecked)
        }
    }
}

/// A heading, a list item, or a line of ordinary text, as a note shows it; see `NoteDisplay`.
public struct NoteDisplayBlock: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case text
        /// 1 for `#`, 2 for `##`, 3 for `###`.
        case heading(level: Int)
        case bullet
        /// The number the note shows in front of the item, such as "3.", counted the way the note counts it.
        case numbered(label: String)
        case task(isChecked: Bool)
    }

    public let kind: Kind
    /// The text you see. A list item's lines continuing it are joined with line breaks, without their indent.
    public let text: String

    public init(kind: Kind, text: String) {
        self.kind = kind
        self.text = text
    }

    /// The block as plain text: a numbered item keeps its number, which the note shows next to it, while a bullet's
    /// dot and a task's box are drawn, so they aren't text you can search for.
    public var plainText: String {
        guard case .numbered(let label) = kind else { return text }
        return label + " " + text
    }
}
