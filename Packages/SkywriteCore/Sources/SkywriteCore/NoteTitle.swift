import Foundation

public enum NoteTitle {
    /// The note's first line with something in it, the way the note shows it (see `NoteDisplay.title`), cut to
    /// `maximumLength` characters. `text` is what's saved in the note's file.
    public static func title(from text: String, maximumLength: Int = NoteMetrics.menuTitleMaximumLength) -> String {
        let title = NoteDisplay(fileText: text).title
        guard title.count > maximumLength else { return title }
        return String(title.prefix(maximumLength)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
