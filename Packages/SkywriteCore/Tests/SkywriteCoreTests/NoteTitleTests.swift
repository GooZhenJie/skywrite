import Testing
@testable import SkywriteCore

struct NoteTitleTests {
    @Test func usesFirstNonBlankLine() {
        #expect(NoteTitle.title(from: "\n\n  买：咖啡豆  \n电池") == "买：咖啡豆")
    }

    @Test func dropsMarkdownHeadingMarks() {
        #expect(NoteTitle.title(from: "## Node 24 升级\n先看 Puppeteer") == "Node 24 升级")
    }

    @Test func blankNoteHasEmptyTitle() {
        #expect(NoteTitle.title(from: "   \n") == "")
    }

    @Test func longLineIsShortenedWithEllipsis() {
        #expect(NoteTitle.title(from: "abcdefghij", maximumLength: 4) == "abcd…")
    }
}
