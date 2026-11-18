import Foundation

/// What's in a note's file: the text of each cell, and how the cells are arranged.
///
/// A plain note's file is just its text. A note with cells starts with a front matter block that names the layout, then
/// starts each cell with an HTML comment, which Markdown viewers don't show, so in any other editor the cells read as one
/// document with the user's own headings intact (Obsidian's Advanced Multi Column plugin splits columns with comments the
/// same way):
///
///     ---
///     skywrite-layout: 2, 2
///     ---
///     <!-- skywrite-cell -->
///     ## P0
///     Ship the fix
///
///     <!-- skywrite-cell -->
///     ## P1
///
/// A cell holds whatever was typed in it. Other front matter lines are kept as they were.
public struct NoteDocument: Equatable, Sendable {
    public static let layoutKey = "skywrite-layout"
    public static let cellMarker = "<!-- skywrite-cell -->"

    public var layout: NoteLayout
    /// One text per cell, in reading order. Always `layout.cellCount` long.
    public private(set) var cells: [String]
    /// Front matter lines other than the layout, kept so another app's settings survive Skywrite saving the note.
    public var otherFrontMatterLines: [String]

    public init(layout: NoteLayout, cells: [String] = [], otherFrontMatterLines: [String] = []) {
        self.layout = layout
        self.cells = Self.fitted(cells, to: layout.cellCount)
        self.otherFrontMatterLines = otherFrontMatterLines
    }

    public static func plain(_ text: String) -> NoteDocument {
        NoteDocument(layout: .single, cells: [text])
    }

    public mutating func setCells(_ newCells: [String]) {
        cells = Self.fitted(newCells, to: layout.cellCount)
    }

    /// True when no cell has anything but spaces and line breaks in it.
    public var isBlank: Bool {
        cells.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// The text to show where a note is listed, such as its title in the menus: every cell, one after another.
    public var readableText: String {
        cells.joined(separator: "\n")
    }

    /// The file's contents.
    public var text: String {
        guard layout.isGrid else { return cells.first ?? "" }
        var lines = ["---", "\(Self.layoutKey): \(layout.description)"] + otherFrontMatterLines + ["---"]
        for (index, cell) in cells.enumerated() {
            if index > 0 {
                lines.append("")
            }
            lines.append(Self.cellMarker)
            if !cell.isEmpty {
                lines += cell.split(separator: "\n", omittingEmptySubsequences: false).map { Self.escaped(String($0)) }
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Reads a note's file. Anything that isn't laid out the way `text` writes it opens as a plain note with the file's
    /// whole text, so nothing in a file edited elsewhere is ever hidden or lost: a missing or unreadable layout, a layout
    /// a new note can't be made with (see `NoteLayout.offered`), text before the first cell, or more cells than the layout
    /// has. Fewer cells leave the last ones empty.
    public static func parse(_ text: String) -> NoteDocument {
        let lines = text.components(separatedBy: "\n")
        guard let frontMatter = frontMatter(in: lines), let layout = frontMatter.layout, layout.isGrid, NoteLayout.offered.contains(layout),
              let sections = sections(in: Array(lines[frontMatter.end...])), sections.count <= layout.cellCount
        else { return NoteDocument.plain(text) }
        let cells = sections.enumerated().map { index, section in
            var lines = section
            // `text` puts one empty line between cells; it isn't part of the cell above.
            if index < sections.count - 1, lines.last == "" {
                lines.removeLast()
            }
            return lines.map(unescaped).joined(separator: "\n")
        }
        return NoteDocument(layout: layout, cells: cells, otherFrontMatterLines: frontMatter.otherLines)
    }

    private struct FrontMatter {
        var layout: NoteLayout?
        var otherLines: [String]
        /// The index of the first line after the block.
        var end: Int
    }

    /// The front matter block the text starts with, if it has one.
    private static func frontMatter(in lines: [String]) -> FrontMatter? {
        guard lines.first == "---", let closing = lines.dropFirst().firstIndex(of: "---") else { return nil }
        var layout: NoteLayout?
        var otherLines: [String] = []
        for line in lines[1..<closing] {
            if let value = value(of: layoutKey, in: line) {
                layout = NoteLayout(description: value)
            } else {
                otherLines.append(line)
            }
        }
        return FrontMatter(layout: layout, otherLines: otherLines, end: closing + 1)
    }

    /// The lines of each cell, or nil when there's text before the first cell.
    private static func sections(in lines: [String]) -> [[String]]? {
        var lines = lines
        if lines.last == "" {
            lines.removeLast()
        }
        var sections: [[String]] = []
        for line in lines.drop(while: \.isEmpty) {
            if line == cellMarker {
                sections.append([])
            } else if sections.isEmpty {
                return nil
            } else {
                sections[sections.count - 1].append(line)
            }
        }
        return sections
    }

    private static func fitted(_ cells: [String], to count: Int) -> [String] {
        Array(cells.prefix(count)) + Array(repeating: "", count: max(0, count - cells.count))
    }

    private static func value(of key: String, in line: String) -> String? {
        let prefix = key + ":"
        guard line.hasPrefix(prefix) else { return nil }
        return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }

    /// A line typed in a cell that reads as the cell marker gets one more backslash in front, and loses it again when read
    /// back, so it never splits the cell in two. Markdown shows a backslash before `<` as a literal `<`.
    private static func escaped(_ line: String) -> String {
        isMarkerAfterBackslashes(line) ? "\\" + line : line
    }

    private static func unescaped(_ line: String) -> String {
        line.hasPrefix("\\") && isMarkerAfterBackslashes(line) ? String(line.dropFirst()) : line
    }

    private static func isMarkerAfterBackslashes(_ line: String) -> Bool {
        String(line.drop { $0 == "\\" }) == cellMarker
    }
}
