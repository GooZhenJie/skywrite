import AppKit
import Testing
@testable import SkywriteCore

/// A note without a fixed width is as wide as its text. These measure text with the same text view setup a note uses.
@MainActor
struct NoteTextLayoutTests {
    let font = NSFont.systemFont(ofSize: NoteMetrics.baseFontSize, weight: .medium)

    func size(of text: String, widthLimit: CGFloat = 1300) -> CGSize {
        let textView = NoteTextLayout.makeTextView(text: text) { NSTextView(frame: .zero, textContainer: $0) }
        textView.typingAttributes = [.font: font]
        textView.textStorage?.setAttributes([.font: font], range: NSRange(location: 0, length: (text as NSString).length))
        return NoteTextLayout.textSize(of: textView, widthLimit: widthLimit, font: font)
    }

    @Test func pressingReturnKeepsTheWidthOfTheText() {
        let typed = size(of: "a")
        #expect(size(of: "a\n").width == typed.width)
        #expect(size(of: "a\n\n").width == typed.width)
    }

    @Test func pressingReturnAddsALineForTheCaret() {
        let oneLine = size(of: "a").height
        #expect(size(of: "a\n").height == oneLine * 2)
        #expect(size(of: "a\n\n").height == oneLine * 3)
    }

    @Test func widthFollowsTheLongestLine() {
        let longLine = size(of: "Hello world")
        #expect(size(of: "Hello world\nhi").width == longLine.width)
        #expect(size(of: "Hello world\nhi\n").width == longLine.width)
        #expect(size(of: "hi\nHello world").width == longLine.width)
    }

    @Test func emptyNoteIsOneLineTall() {
        let empty = size(of: "")
        #expect(empty.width == 0)
        #expect(empty.height == size(of: "a").height)
    }

    @Test func longTextWrapsWithinTheLimit() {
        let text = String(repeating: "word ", count: 80)
        let wrapped = size(of: text, widthLimit: 300)
        #expect(wrapped.width <= 300)
        #expect(wrapped.height > size(of: "a").height * 2)
        #expect(size(of: text + "\n", widthLimit: 300).width == wrapped.width)
    }
}
