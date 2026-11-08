import AppKit

/// Builds a note's text view and measures the space its text takes up.
///
/// The app and the unit tests both go through here, so the tests measure text exactly the way a note sizes itself.
@MainActor
public enum NoteTextLayout {
    /// Creates the text storage, layout manager and container a note uses, then the text view on top of them.
    ///
    /// The container doesn't follow the text view's size: a note sets the container's width itself before measuring,
    /// and lines start right at the container's edge, with no padding of their own.
    public static func makeTextView<View: NSTextView>(text: String, _ makeView: (NSTextContainer) -> View) -> View {
        let textStorage = NSTextStorage(string: text)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: .zero)
        container.widthTracksTextView = false
        container.heightTracksTextView = false
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)
        return makeView(container)
    }

    /// The size the text takes up when lines may be at most `widthLimit` wide, rounded up to whole points.
    ///
    /// The width is that of the longest line. `usedRect(for:)` can't be used for it: when the text ends with a newline,
    /// the empty line after it (where the caret sits) spans the whole container once a text view is attached, so a note
    /// would jump to the full width as soon as you press Return. The height does count that empty line, so the caret
    /// has room, and is never less than one line.
    public static func textSize(of textView: NSTextView, widthLimit: CGFloat, font: NSFont) -> CGSize {
        guard let container = textView.textContainer, let layoutManager = textView.layoutManager else { return .zero }
        container.size = NSSize(width: max(1, widthLimit), height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: container)
        var widestLine: CGFloat = 0
        let glyphs = NSRange(location: 0, length: layoutManager.numberOfGlyphs)
        layoutManager.enumerateLineFragments(forGlyphRange: glyphs) { _, usedRect, _, _, _ in
            widestLine = max(widestLine, usedRect.width)
        }
        let usedHeight = layoutManager.usedRect(for: container).height
        let lineHeight = layoutManager.defaultLineHeight(for: font)
        return CGSize(width: ceil(widestLine), height: max(ceil(usedHeight), lineHeight))
    }
}
