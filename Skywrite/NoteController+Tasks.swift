import AppKit
import SkywriteCore

/// Task items: a box in front of the text that a click ticks, typed as `[]` and a space the way Notion's to-dos are, and
/// saved as GitHub's task list (`- [ ] `, `- [x] `) so other Markdown apps show the same boxes.
///
/// A click on a box ticks it even while the note is locked, the way Notion ticks a to-do and Obsidian's Reading view
/// ticks a task, and the note stays locked. Pressing on a box and dragging still moves the note, since a drag is told
/// apart before the button comes up. A click on a box doesn't count as the click that unlocks the note, so clicking a
/// box twice quickly ticks it and unticks it rather than closing the note. Both are on purpose, and so is a click meant
/// to unlock the note ticking a box when it lands on one.
extension NoteController {
    /// The cell and task item whose box is under `point`, in the note view's coordinates.
    func taskBox(at point: NSPoint) -> (cell: NoteTextView, characterIndex: Int)? {
        guard let cell = cell(at: point), let marker = cell.taskMarker(at: cell.convert(point, from: noteView)) else { return nil }
        return (cell, marker.characterIndex)
    }

    /// Ticks the task item that starts at `characterIndex`, or unticks it. While typing, the change goes through the
    /// text view so Undo takes it back, and the caret stays where it was; a locked note changes its text and stays locked.
    func toggleTask(startingAt characterIndex: Int, in cell: NoteTextView) {
        guard let item = NoteMarkdown.listItems(in: cell.string).first(where: { $0.lineRange.location == characterIndex }), let range = item.checkMarkRange else { return }
        let mark = item.isChecked ? " " : "x"
        EventLog.notes.notice("toggle task \(self.panel.identifier?.rawValue ?? "", privacy: .public) checked=\(!item.isChecked, privacy: .public) editing=\(self.isEditing, privacy: .public)")
        forgetUnlockClick()
        guard isEditing else {
            cell.textStorage?.replaceCharacters(in: range, with: mark)
            textDidChange(Notification(name: NSText.didChangeNotification, object: cell))
            return
        }
        let selection = cell.selectedRanges
        guard cell.shouldChangeText(in: range, replacementString: mark) else { return }
        cell.textStorage?.replaceCharacters(in: range, with: mark)
        cell.didChangeText()
        cell.selectedRanges = selection
    }

    /// A space typed right after `[]` or `【】` at the start of a line (or of a bulleted or numbered item) turns them into
    /// a box instead; see `NoteMarkdown.taskMarker(replacing:)`. The space can be a full-width one, which Chinese
    /// punctuation may type. Returns false when the space should be typed as usual.
    func convertTaskShortcut(in cell: NoteTextView, typing text: String) -> Bool {
        guard text == " " || text == "\u{3000}", !cell.hasMarkedText() else { return false }
        let selection = cell.selectedRange()
        guard selection.length == 0 else { return false }
        let string = cell.string as NSString
        let lineStart = string.lineRange(for: NSRange(location: selection.location, length: 0)).location
        let typed = NSRange(location: lineStart, length: selection.location - lineStart)
        guard let marker = NoteMarkdown.taskMarker(replacing: string.substring(with: typed)) else { return false }
        return replace(typed, with: marker, in: cell)
    }
}
