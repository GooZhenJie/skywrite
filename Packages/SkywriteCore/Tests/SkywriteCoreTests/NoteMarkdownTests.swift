import Foundation
import Testing
@testable import SkywriteCore

struct NoteMarkdownTests {
    @Test func headingsUpToThreeLevels() {
        let text = "# One\n## Two\n### Three\n#### Four\n#tag\nplain ## not\n##\n"
        let headings = NoteMarkdown.headings(in: text)
        #expect(headings.map(\.level) == [1, 2, 3, 2])
        #expect(headings.map { (text as NSString).substring(with: $0.markerRange) } == ["# ", "## ", "### ", "##"])
        #expect(headings.map { (text as NSString).substring(with: $0.lineRange) } == ["# One", "## Two", "### Three", "##"])
    }

    @Test func rangesCountUTF16LikeTheTextView() {
        let text = "表情 😀\n## 标题 😀\n"
        let heading = NoteMarkdown.headings(in: text)[0]
        #expect((text as NSString).substring(with: heading.lineRange) == "## 标题 😀")
        #expect(heading.markerRange == NSRange(location: 6, length: 3))
    }

    @Test func copyingLeavesOutTheHashMarks() {
        let text = "## P0 (soon)\n- [ ] first thing\n### detail"
        let all = NSRange(location: 0, length: (text as NSString).length)
        #expect(NoteMarkdown.plainText(of: text, in: all) == "P0 (soon)\n- [ ] first thing\ndetail")
    }

    @Test func copyingPartOfALineKeepsWhatWasSelected() {
        let text = "## P0 (soon)\nbody"
        #expect(NoteMarkdown.plainText(of: text, in: NSRange(location: 1, length: 4)) == "P0")
        #expect(NoteMarkdown.plainText(of: text, in: NSRange(location: 3, length: 2)) == "P0")
        #expect(NoteMarkdown.plainText(of: text, in: NSRange(location: 13, length: 4)) == "body")
    }

    @Test func otherMarkdownIsCopiedAsTyped() {
        let text = "- [ ] **bold** [link](https://example.com)\n#### four"
        let all = NSRange(location: 0, length: (text as NSString).length)
        #expect(NoteMarkdown.plainText(of: text, in: all) == text)
    }

    @Test func headingSizesFollowGitHub() {
        #expect(NoteMarkdown.headingScales == [2, 1.5, 1.25])
    }
}
