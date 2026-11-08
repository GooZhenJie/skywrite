import Foundation
import Testing
@testable import SkywriteCore

struct LogFileTests {
    private let folder: URL
    private let utc = TimeZone(identifier: "UTC")!
    private let date = Date(timeIntervalSince1970: 60)

    init() throws {
        folder = FileManager.default.temporaryDirectory.appending(path: "SkywriteCoreTests-\(UUID().uuidString)")
    }

    /// Each line written by these tests is 47 bytes ("1970-01-01 00:01:00.000 +0000 [42] app: line 1\n"), so with a
    /// 100-byte limit two lines fit in a file and the third starts a new one.
    private func makeLog() -> LogFile {
        LogFile(folder: folder, maximumSize: 100, timeZone: utc, processIdentifier: 42)
    }

    private func line(_ number: Int) -> String {
        "1970-01-01 00:01:00.000 +0000 [42] app: line \(number)\n"
    }

    @Test func writesOneLinePerEventWithTheTimeProcessAndCategory() {
        let log = LogFile(folder: folder, timeZone: utc, processIdentifier: 42)
        log.append(category: "notes", level: nil, message: "close note blank=false", date: date)
        log.append(category: "app", level: "error", message: "could not save", date: date)
        #expect(log.contents() == "1970-01-01 00:01:00.000 +0000 [42] notes: close note blank=false\n1970-01-01 00:01:00.000 +0000 [42] app error: could not save\n")
    }

    @Test func nothingWrittenMeansNothingToExport() {
        #expect(makeLog().contents().isEmpty)
    }

    @Test func aFullFileBecomesThePreviousOneAndOnlyTwoAreKept() throws {
        let log = makeLog()
        for number in 1...5 {
            log.append(category: "app", level: nil, message: "line \(number)", date: date)
        }
        #expect(log.contents() == line(3) + line(4) + line(5))
        #expect(try String(contentsOf: log.previousURL, encoding: .utf8) == line(3) + line(4))
        #expect(try String(contentsOf: log.currentURL, encoding: .utf8) == line(5))
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        #expect(files == ["Skywrite.log", "Skywrite.previous.log"])
    }

    @Test func aRestartedAppCountsWhatIsAlreadyInTheFile() throws {
        let before = makeLog()
        before.append(category: "app", level: nil, message: "line 1", date: date)
        before.append(category: "app", level: nil, message: "line 2", date: date)
        _ = before.contents()

        let after = makeLog()
        after.append(category: "app", level: nil, message: "line 3", date: date)

        #expect(after.contents() == line(1) + line(2) + line(3))
        #expect(try String(contentsOf: after.previousURL, encoding: .utf8) == line(1) + line(2))
        #expect(try String(contentsOf: after.currentURL, encoding: .utf8) == line(3))
    }

    @Test func theStandardLimitIsTenMebibytes() {
        #expect(LogFile.standardMaximumSize == 10_485_760)
    }
}
