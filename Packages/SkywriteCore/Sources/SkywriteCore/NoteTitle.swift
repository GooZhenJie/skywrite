import Foundation

public enum NoteTitle {
    public static func title(from text: String, maximumLength: Int = NoteMetrics.menuTitleMaximumLength) -> String {
        // A note with cells starts with its layout; its title comes from the cells, the way the note shows them.
        let line = NoteDocument.parse(text).readableText.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        let withoutHeading = line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
        guard withoutHeading.count > maximumLength else { return withoutHeading }
        return String(withoutHeading.prefix(maximumLength)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
