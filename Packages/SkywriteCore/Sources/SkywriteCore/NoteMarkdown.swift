import CoreGraphics
import Foundation

/// The bit of Markdown Skywrite draws: headings made with `#`, `##` and `###` at the start of a line, and lists (see
/// `listItems(in:)`).
///
/// Everything else is shown as typed. Copying leaves out the `#` marks, so text pasted elsewhere reads the way the note
/// looked, unlike Raycast Notes, which copies the raw Markdown.
public enum NoteMarkdown {
    /// How much bigger than the note's text each heading level is: GitHub's sizes for h1, h2 and h3 (`2em`, `1.5em`,
    /// `1.25em` in github-markdown-css 5.8.1). Only three levels, like Notion; `####` stays ordinary text.
    public static let headingScales: [CGFloat] = [2, 1.5, 1.25]

    public struct Heading: Equatable, Sendable {
        /// 1 for `#`, 2 for `##`, 3 for `###`.
        public let level: Int
        /// The whole line, without its line break, in UTF-16 units the way `NSString` counts.
        public let lineRange: NSRange
        /// The `#` marks and the spaces after them.
        public let markerRange: NSRange
    }

    /// Every heading in `text`. A heading is one to three `#` at the very start of a line, followed by a space or the
    /// end of the line, the way Markdown writes one; `#tag` and `####` aren't headings.
    public static func headings(in text: String) -> [Heading] {
        let string = text as NSString
        var headings: [Heading] = []
        var location = 0
        while location < string.length {
            var lineEnd = 0
            var contentsEnd = 0
            string.getLineStart(nil, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: location, length: 0))
            let lineRange = NSRange(location: location, length: contentsEnd - location)
            if let marker = marker(in: string.substring(with: lineRange)) {
                headings.append(Heading(level: marker.level, lineRange: lineRange, markerRange: NSRange(location: location, length: marker.length)))
            }
            location = lineEnd
        }
        return headings
    }

    /// The text in `range` with the `#` marks of any heading in it left out: what copying a note's selection gives.
    public static func plainText(of text: String, in range: NSRange) -> String {
        let string = text as NSString
        let range = NSIntersectionRange(range, NSRange(location: 0, length: string.length))
        let result = NSMutableString(string: string.substring(with: range))
        for heading in headings(in: text).reversed() {
            let cut = NSIntersectionRange(heading.markerRange, range)
            guard cut.length > 0 else { continue }
            result.deleteCharacters(in: NSRange(location: cut.location - range.location, length: cut.length))
        }
        return result as String
    }

    private static func marker(in line: String) -> (level: Int, length: Int)? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...headingScales.count).contains(hashes) else { return nil }
        let rest = line.dropFirst(hashes)
        guard rest.isEmpty || rest.first == " " || rest.first == "\t" else { return nil }
        let spaces = rest.prefix { $0 == " " || $0 == "\t" }.count
        return (hashes, (String(line.prefix(hashes + spaces)) as NSString).length)
    }
}
