import Foundation
import Testing
@testable import SkywriteCore

struct NoteSearchTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func note(_ text: String, hoursAgo: Double, onScreen: Bool = false, pinned: Bool = false) -> SearchableNote {
        let modified = now.addingTimeInterval(-hoursAgo * 3600)
        return SearchableNote(id: UUID(), fileText: text, fileName: "x.md", modifiedAt: modified, createdAt: modified, isOnScreen: onScreen, isPinned: pinned)
    }

    @Test func searchLooksAtWhatTheNoteShowsNotItsFile() {
        let grid = note(NoteDocument(layout: .twoByTwo, cells: ["## P0\n- [ ] ship the fix", "", "", ""]).text, hoursAgo: 1)
        for query in ["skywrite", "cell", "layout", "##", "[ ]", "-"] {
            #expect(NoteSearch.sections(for: [grid], query: query, filter: .all, now: now, calendar: calendar).isEmpty, "\(query)")
        }
        let match = NoteSearch.sections(for: [grid], query: "fix", filter: .all, now: now, calendar: calendar).first?.matches.first
        #expect(match?.title == "P0")
        #expect(match?.excerpt == "ship the fix")
    }

    @Test func withoutQueryGroupsPinnedTodayAndEarlier() {
        let wifi = note("WiFi 密码在路由器背面", hoursAgo: 30, pinned: true)
        let call = note("给陈小姐回电话", hoursAgo: 0.1, onScreen: true)
        let milk = note("买牛奶、鸡蛋", hoursAgo: 1)
        let flight = note("SQ 106 08:45 起飞", hoursAgo: 40)
        let sections = NoteSearch.sections(for: [flight, milk, wifi, call], query: "", filter: .all, now: now, calendar: calendar)
        #expect(sections.map(\.kind) == [.pinned, .today, .earlier])
        #expect(sections[0].matches.map(\.id) == [wifi.id])
        #expect(sections[1].matches.map(\.id) == [call.id, milk.id])
        #expect(sections[2].matches.map(\.id) == [flight.id])
    }

    @Test func emptySectionsAreLeftOut() {
        let milk = note("买牛奶", hoursAgo: 1)
        let sections = NoteSearch.sections(for: [milk], query: "  ", filter: .all, now: now, calendar: calendar)
        #expect(sections.map(\.kind) == [.today])
    }

    @Test func filtersKeepOnlyNotesOnScreenOrPinned() {
        let onScreen = note("on screen", hoursAgo: 1, onScreen: true)
        let pinned = note("pinned", hoursAgo: 2, pinned: true)
        let closed = note("closed", hoursAgo: 3)
        let all = [onScreen, pinned, closed]
        #expect(NoteSearch.sections(for: all, query: "", filter: .onScreen, now: now, calendar: calendar).flatMap(\.matches).map(\.id) == [onScreen.id])
        #expect(NoteSearch.sections(for: all, query: "", filter: .pinned, now: now, calendar: calendar).flatMap(\.matches).map(\.id) == [pinned.id])
    }

    @Test func findsWordsBelowTheFirstLine() throws {
        let meeting = note("周会\n下周一 10 点\n把报告模板放到共享盘", hoursAgo: 700)
        let sections = NoteSearch.sections(for: [meeting], query: "报告", filter: .all, now: now, calendar: calendar)
        let match = try #require(sections.first?.matches.first)
        #expect(match.title == "周会")
        #expect(match.titleMatches.isEmpty)
        #expect(match.excerpt == "把报告模板放到共享盘")
        #expect(match.excerptMatches.map { String(match.excerpt![$0]) } == ["报告"])
    }

    @Test func notesWithTheWordInTheTitleComeFirst() {
        let older = note("Q4 报告大纲", hoursAgo: 50)
        let newer = note("周会\n把报告模板放到共享盘", hoursAgo: 2)
        let sections = NoteSearch.sections(for: [newer, older], query: "报告", filter: .all, now: now, calendar: calendar)
        #expect(sections.map(\.kind) == [.results])
        #expect(sections[0].matches.map(\.id) == [older.id, newer.id])
        #expect(sections[0].matches[0].excerpt == nil)
        #expect(sections[0].matches[0].titleMatches.map { String(sections[0].matches[0].title[$0]) } == ["报告"])
    }

    @Test func everyWordHasToBeSomewhereInTheNote() {
        let both = note("Shopping\nmilk and eggs", hoursAgo: 1)
        let one = note("milk", hoursAgo: 1)
        let sections = NoteSearch.sections(for: [both, one], query: "eggs milk", filter: .all, now: now, calendar: calendar)
        #expect(sections.flatMap(\.matches).map(\.id) == [both.id])
    }

    @Test func ignoresCaseAndAccents() {
        let cafe = note("Café with Ken", hoursAgo: 1)
        #expect(NoteSearch.sections(for: [cafe], query: "CAFE", filter: .all, now: now, calendar: calendar).flatMap(\.matches).count == 1)
    }

    @Test func titleDropsMarkdownHeadingMarks() {
        let heading = note("## Groceries\n- milk", hoursAgo: 1)
        #expect(heading.title == "Groceries")
    }

    @Test func blankNoteFallsBackToItsFileName() {
        let blank = SearchableNote(id: UUID(), fileText: "  \n ", fileName: "2026-11-17 09.00.00.md", modifiedAt: now, createdAt: now, isOnScreen: false, isPinned: false)
        #expect(blank.title == "2026-11-17 09.00.00.md")
    }

    @Test func longLineIsCutInFrontOfTheMatch() throws {
        let long = note("Notes\nThe quarterly figures are due on Friday together with the report for Ken", hoursAgo: 1)
        let match = try #require(NoteSearch.match(long, terms: ["report"]))
        let excerpt = try #require(match.excerpt)
        #expect(excerpt.hasPrefix("…"))
        #expect(excerpt.contains("report for Ken"))
        #expect(excerpt.count < "The quarterly figures are due on Friday together with the report for Ken".count)
    }

    @Test func matchNearTheStartKeepsTheLineWhole() throws {
        let shopping = note("Shopping\nmilk and eggs", hoursAgo: 1)
        let match = try #require(NoteSearch.match(shopping, terms: ["eggs"]))
        #expect(match.excerpt == "milk and eggs")
    }

    @Test func noMatchGivesNoSections() {
        let milk = note("买牛奶", hoursAgo: 1)
        #expect(NoteSearch.sections(for: [milk], query: "发票", filter: .all, now: now, calendar: calendar).isEmpty)
    }
}
