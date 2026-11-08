import Foundation

public enum NoteTitle {
    public static func title(from text: String, maximumLength: Int = NoteMetrics.menuTitleMaximumLength) -> String {
        let line = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        let withoutHeading = line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
        guard withoutHeading.count > maximumLength else { return withoutHeading }
        return String(withoutHeading.prefix(maximumLength)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
