import Foundation
import SkywriteCore
import Testing

@Suite struct LogReportTests {
    private let scrubber = LogScrubber(homeDirectory: "/Users/simon", names: ["simon", "Simon Goo"])
    private let utc8 = TimeZone(secondsFromGMT: 8 * 3600)!

    @Test func hidesTheHomeFolderAndTheUserNames() {
        let text = "notes folder=/Users/simon/Documents/Notes owner=Simon Goo user=simon"
        #expect(scrubber.scrub(text) == "notes folder=~/Documents/Notes owner=<user> user=<user>")
    }

    @Test func leavesWordsThatOnlyContainTheNameAlone() {
        let scrubber = LogScrubber(homeDirectory: "/Users/goo", names: ["goo"])
        #expect(scrubber.scrub("activate from com.google.Chrome by Goo") == "activate from com.google.Chrome by <user>")
    }

    @Test func ignoresOneLetterNames() {
        let scrubber = LogScrubber(homeDirectory: "/Users/a", names: ["a"])
        #expect(scrubber.scrub("a note at /Users/a/Notes") == "a note at ~/Notes")
    }

    @Test func writesAHeaderThenTheLog() {
        let log = "2026-11-07 16:12:09.513 +0800 [42] settings: export logs started\n2026-11-07 16:12:10.001 +0800 [42] notes: close note blank=false\n"
        let report = LogReport(log: log, appVersion: "0.1.0 (1)", systemVersion: "27.2 (Build 27C5)", exportedAt: Date(timeIntervalSince1970: 60))
        let lines = report.text(timeZone: utc8, scrubber: scrubber).split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines[0] == "Skywrite 0.1.0 (1)")
        #expect(lines[1] == "macOS 27.2 (Build 27C5)")
        #expect(lines[2] == "Exported 1970-01-01 08:01:00 +0800")
        #expect(lines[3] == "Lines 2")
        #expect(lines[6] == "2026-11-07 16:12:09.513 +0800 [42] settings: export logs started")
        #expect(lines[7] == "2026-11-07 16:12:10.001 +0800 [42] notes: close note blank=false")
    }

    @Test func endsWithANewlineEvenWhenTheLogDoesNot() {
        let report = LogReport(log: "one line", appVersion: "0.1.0 (1)", systemVersion: "27.2", exportedAt: Date())
        #expect(report.text(scrubber: scrubber).hasSuffix("one line\n"))
    }

    @Test func scrubsTheLog() {
        let report = LogReport(log: "app: folder /Users/simon/Notes\n", appVersion: "0.1.0 (1)", systemVersion: "27.2", exportedAt: Date())
        let text = report.text(scrubber: scrubber)
        #expect(text.contains("app: folder ~/Notes"))
        #expect(!text.contains("simon"))
    }
}
