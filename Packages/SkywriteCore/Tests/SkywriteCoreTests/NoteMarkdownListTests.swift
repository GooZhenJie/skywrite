import Foundation
import Testing
@testable import SkywriteCore

struct NoteMarkdownListTests {
    @Test func bulletsStartWithADashStarOrPlusAndASpace() {
        let items = NoteMarkdown.listItems(in: "- apple\n* pear\n+ plum")
        #expect(items.map(\.kind) == [.bullet, .bullet, .bullet])
        #expect(items.map(\.label) == ["•", "•", "•"])
        #expect(items.map(\.markerRange) == [NSRange(location: 0, length: 2), NSRange(location: 8, length: 2), NSRange(location: 15, length: 2)])
        #expect(items.map(\.nextMarker) == ["- ", "* ", "+ "])
    }

    @Test func lookalikesAreNotLists() {
        for text in ["-apple", "---", "**bold**", "  - indented", "#- x", "1.5 litres", "2026 was", "1.", "-"] {
            #expect(NoteMarkdown.listItems(in: text).isEmpty, "\(text)")
        }
    }

    @Test func anEmptyItemIsStillAnItem() {
        let items = NoteMarkdown.listItems(in: "- apple\n- ")
        #expect(items.count == 2)
        #expect(items[1].isEmpty)
        #expect(!items[0].isEmpty)
    }

    @Test func numbersCountFromTheFirstItemWhateverWasTyped() {
        let items = NoteMarkdown.listItems(in: "1. one\n1. two\n5. three")
        #expect(items.map(\.label) == ["1.", "2.", "3."])
        #expect(items.map(\.nextMarker) == ["2. ", "3. ", "4. "])
        #expect(items[2].markerRange == NSRange(location: 14, length: 3))
    }

    @Test func aListCanStartAtAnyNumber() {
        #expect(NoteMarkdown.listItems(in: "7) seven\n1) eight").map(\.label) == ["7)", "8)"])
    }

    @Test func aBlankLineOrOtherTextStartsANewList() {
        #expect(NoteMarkdown.listItems(in: "1. a\n2. b\n\n1. c\n2. d").map(\.label) == ["1.", "2.", "1.", "2."])
        #expect(NoteMarkdown.listItems(in: "1. a\ntext\n1. b").map(\.label) == ["1.", "1."])
        #expect(NoteMarkdown.listItems(in: "1. a\n- b\n1. c").map(\.label) == ["1.", "•", "1."])
        #expect(NoteMarkdown.listItems(in: "1. a\n1) b").map(\.label) == ["1.", "1)"])
    }

    @Test func indentedLinesBelowAnItemContinueIt() {
        let text = "- apple\n  red\n  green\n- pear\n  \nplain"
        let items = NoteMarkdown.listItems(in: text)
        #expect(items.count == 2)
        #expect(items[0].continuationLines == [NSRange(location: 8, length: 5), NSRange(location: 14, length: 7)])
        #expect(items[0].continuationIndents == [NSRange(location: 8, length: 2), NSRange(location: 14, length: 2)])
        #expect(items[0].textRange == NSRange(location: 2, length: 19))
        #expect(items[1].continuationLines == [NSRange(location: 29, length: 2)])
        let numbered = NoteMarkdown.listItems(in: "10. ten\n    more\n  not enough")
        #expect(numbered[0].continuationLines == [NSRange(location: 8, length: 8)])
    }

    @Test func titlesLeaveOutBulletsButKeepNumbers() {
        #expect(NoteTitle.title(from: "- buy milk\n- eggs") == "buy milk")
        #expect(NoteTitle.title(from: "1. step one") == "1. step one")
        #expect(NoteTitle.title(from: "-x") == "-x")
    }
}

struct NoteMarkdownTaskTests {
    @Test func aTaskIsABulletWithABoxAndASpace() {
        let items = NoteMarkdown.listItems(in: "- [ ] milk\n* [x] eggs\n+ [X] tea")
        #expect(items.map(\.kind) == [.task(isChecked: false), .task(isChecked: true), .task(isChecked: true)])
        #expect(items.map(\.isChecked) == [false, true, true])
        #expect(items.map(\.markerRange) == [NSRange(location: 0, length: 6), NSRange(location: 11, length: 6), NSRange(location: 22, length: 6)])
        #expect(items.map(\.checkMarkRange) == [NSRange(location: 3, length: 1), NSRange(location: 14, length: 1), NSRange(location: 25, length: 1)])
        // Return always starts an unticked box.
        #expect(items.map(\.nextMarker) == ["- [ ] ", "* [ ] ", "+ [ ] "])
    }

    @Test func boxLookalikesStayBulletsOrText() {
        for text in ["- [] milk", "- [y] milk", "- [x]milk", "- [ ]"] {
            #expect(NoteMarkdown.listItems(in: text).map(\.kind) == [.bullet], "\(text)")
        }
        #expect(NoteMarkdown.listItems(in: "[ ] milk").isEmpty)
        #expect(NoteMarkdown.listItems(in: "- milk")[0].checkMarkRange == nil)
    }

    @Test func anEmptyTaskIsStillATask() {
        let items = NoteMarkdown.listItems(in: "- [x] milk\n- [ ] ")
        #expect(items.map(\.kind) == [.task(isChecked: true), .task(isChecked: false)])
        #expect(items[1].isEmpty)
    }

    @Test func linesContinuingATaskAreIndentedPastItsBox() {
        let items = NoteMarkdown.listItems(in: "- [x] milk\n      2 litres\n  not enough")
        #expect(items.count == 1)
        #expect(items[0].continuationLines == [NSRange(location: 11, length: 14)])
        #expect(items[0].visibleTextRanges == [NSRange(location: 6, length: 4), NSRange(location: 17, length: 8)])
    }

    @Test func aTaskEndsANumberedList() {
        #expect(NoteMarkdown.listItems(in: "1. a\n- [ ] b\n1. c").map(\.label) == ["1.", "", "1."])
    }

    @Test func bracketsThenASpaceTurnIntoABox() {
        #expect(NoteMarkdown.taskMarker(replacing: "[]") == "- [ ] ")
        #expect(NoteMarkdown.taskMarker(replacing: "【】") == "- [ ] ")
        #expect(NoteMarkdown.taskMarker(replacing: "* []") == "* [ ] ")
        #expect(NoteMarkdown.taskMarker(replacing: "- 【】") == "- [ ] ")
        #expect(NoteMarkdown.taskMarker(replacing: "3. []") == "- [ ] ")
        for typed in ["", "[", "[x]", "[ ]", "【重要】", "a[]", " []", "- [ ] []", "# []"] {
            #expect(NoteMarkdown.taskMarker(replacing: typed) == nil, "\(typed)")
        }
    }

    @Test func titlesLeaveOutTheBox() {
        #expect(NoteTitle.title(from: "- [x] buy milk") == "buy milk")
        #expect(NoteTitle.title(from: "- [ ] buy milk\n- eggs") == "buy milk")
    }
}
