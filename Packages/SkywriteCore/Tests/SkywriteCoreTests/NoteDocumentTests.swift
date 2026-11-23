import Testing
@testable import SkywriteCore

struct NoteDocumentTests {
    let fourCells = ["P0 (within the next few days)", "P1 (by this week)\nweb-region: pageCache\nClass Stats", "P2\n", "\nno heading"]

    @Test func plainNoteFileIsItsText() {
        let document = NoteDocument.plain("买：咖啡豆\n电池\n")
        #expect(document.text == "买：咖啡豆\n电池\n")
        #expect(NoteDocument.parse("买：咖啡豆\n电池\n") == document)
    }

    @Test func gridFileStartsEachCellWithAComment() {
        let document = NoteDocument(layout: .twoByTwo, cells: ["## P0", "## P1\nweb-region", "", "P3\n"])
        #expect(document.text == """
        ---
        skywrite-layout: 2, 2
        ---
        <!-- skywrite-cell -->
        ## P0

        <!-- skywrite-cell -->
        ## P1
        web-region

        <!-- skywrite-cell -->

        <!-- skywrite-cell -->
        P3


        """)
    }

    @Test(arguments: [
        ["P0 (within the next few days)", "P1 (by this week)\nweb-region: pageCache\nClass Stats", "P2\n", "\nno heading"],
        ["", "", "", ""],
        ["a\n\n\n", "\n", "b\n\nc", "d\n\n"],
        ["## looks like a heading\n## inside", "body\n##\n\\## already escaped", "#\n###\n# one", "\\\\## two backslashes"],
        ["<!-- skywrite-cell -->", "a\n<!-- skywrite-cell -->\nb", "\\<!-- skywrite-cell -->", "\\\\<!-- skywrite-cell -->\n"]
    ])
    func everyCellComesBackExactly(cells: [String]) {
        let document = NoteDocument(layout: .twoByTwo, cells: cells)
        #expect(NoteDocument.parse(document.text).cells == cells)
    }

    @Test func headingsTypedInACellStayHeadings() {
        let document = NoteDocument(layout: .twoByTwo, cells: ["## P0\n### detail", "", "", ""])
        #expect(document.text.contains("\n## P0\n### detail\n"))
        #expect(NoteDocument.parse(document.text).cells[0] == "## P0\n### detail")
    }

    @Test func markerTypedInsideACellDoesNotSplitIt() {
        let document = NoteDocument(layout: .twoByTwo, cells: ["a\n<!-- skywrite-cell -->\nb", "", "", ""])
        #expect(document.text.contains("\\<!-- skywrite-cell -->"))
        #expect(NoteDocument.parse(document.text).cells[0] == "a\n<!-- skywrite-cell -->\nb")
    }

    @Test func layoutsNoMenuOffersOpenAsPlainText() throws {
        let layout = try #require(NoteLayout(cellsPerRow: [3, 1]))
        let document = NoteDocument(layout: layout, cells: ["a", "b", "c", "d"])
        #expect(document.text.hasPrefix("---\nskywrite-layout: 3, 1\n---\n"))
        #expect(NoteDocument.parse(document.text) == .plain(document.text))
    }

    @Test func otherFrontMatterIsKept() {
        let text = "---\nskywrite-layout: 2,2\ntags: todo\n---\n<!-- skywrite-cell -->\nP0\n"
        let document = NoteDocument.parse(text)
        #expect(document.layout == .twoByTwo)
        #expect(document.otherFrontMatterLines == ["tags: todo"])
        #expect(document.text.contains("tags: todo\n---"))
    }

    @Test func missingCellsAreEmpty() {
        let document = NoteDocument.parse("---\nskywrite-layout: 2, 2\n---\n\n<!-- skywrite-cell -->\n## P0\n")
        #expect(document.cells == ["## P0", "", "", ""])
    }

    @Test(arguments: [
        "---\ntags: todo\n---\n<!-- skywrite-cell -->\nP0\n",
        "---\nskywrite-layout: two\n---\n<!-- skywrite-cell -->\nP0\n",
        "---\nskywrite-layout: 2, 0\n---\n<!-- skywrite-cell -->\nP0\n",
        "---\nskywrite-layout: 1\n---\n<!-- skywrite-cell -->\nP0\n",
        "---\nskywrite-layout: 2, 2\n---\ntext before the first cell\n<!-- skywrite-cell -->\nP0\n",
        "---\nskywrite-layout: 2, 2\n---\n<!-- skywrite-cell -->\n<!-- skywrite-cell -->\n<!-- skywrite-cell -->\n<!-- skywrite-cell -->\n<!-- skywrite-cell -->\n",
        "---\nskywrite-layout: 2, 2\n<!-- skywrite-cell -->\nP0\n",
        "<!-- skywrite-cell -->\nP0\n",
        "---\nskywrite-layout: 2, 2\n---\n\n## P0\n\n## P1\n",
        // Layouts no menu offers, including ones that would stall or crash the app if they were built.
        "---\nskywrite-layout: 3, 3\n---\n<!-- skywrite-cell -->\nP0\n",
        "---\nskywrite-layout: 100000\n---\n<!-- skywrite-cell -->\nP0\n",
        "---\nskywrite-layout: 9223372036854775807, 9223372036854775807\n---\n<!-- skywrite-cell -->\nP0\n"
    ])
    func anythingElseOpensAsPlainTextSoNothingIsHidden(text: String) {
        let document = NoteDocument.parse(text)
        #expect(document.layout == .single)
        #expect(document.text == text)
    }

    @Test(arguments: NoteLayout.offered.filter(\.isGrid))
    func everyOfferedLayoutOpensWithItsCells(layout: NoteLayout) {
        let cells = (0..<layout.cellCount).map { "## Cell \($0 + 1)\nnotes" }
        let document = NoteDocument(layout: layout, cells: cells)
        #expect(NoteDocument.parse(document.text) == document)
    }

    @Test func blankWhenEveryCellIsBlank() {
        #expect(NoteDocument(layout: .twoByTwo, cells: [" ", "\n", "", ""]).isBlank)
        #expect(!NoteDocument(layout: .twoByTwo, cells: ["", "", "", "x"]).isBlank)
    }

    @Test func layoutReadsWhatItWrites() {
        #expect(NoteLayout(description: "2, 2") == .twoByTwo)
        #expect(NoteLayout(description: " 2,2 ") == .twoByTwo)
        #expect(NoteLayout(description: "2,,2") == nil)
        #expect(NoteLayout(description: "") == nil)
        #expect(NoteLayout.twoByTwo.rows == [0..<2, 2..<4])
    }
}
