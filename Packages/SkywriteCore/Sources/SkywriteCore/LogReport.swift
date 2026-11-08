import Foundation

/// The text file you send the developer when Skywrite misbehaves: a short header saying which version and macOS it came
/// from, then Skywrite's own log, oldest line first.
///
/// Skywrite logs what it does (notes opening, moving and closing, which app was in front), never what you wrote in a
/// note. Your home folder and user name are hidden before anything is written, the way other Mac apps that export logs
/// for support do (Purrchiver shows them as `<redacted>`: https://purrchiver.pages.dev/help/diagnostic-logs/, read 2026-11-07).
public struct LogReport: Sendable {
    public var log: String
    public var appVersion: String
    public var systemVersion: String
    public var exportedAt: Date

    public init(log: String, appVersion: String, systemVersion: String, exportedAt: Date) {
        self.log = log
        self.appVersion = appVersion
        self.systemVersion = systemVersion
        self.exportedAt = exportedAt
    }

    public func text(timeZone: TimeZone = .current, scrubber: LogScrubber) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss xx"
        let lines = log.split(separator: "\n", omittingEmptySubsequences: true).count
        let header = [
            "Skywrite \(appVersion)",
            "macOS \(systemVersion)",
            "Exported \(formatter.string(from: exportedAt))",
            "Lines \(lines)",
            "Your home folder is shown as ~ and your user name as \(LogScrubber.placeholder). Notes' text is never logged.",
            ""
        ]
        let body = log.isEmpty || log.hasSuffix("\n") ? log : log + "\n"
        return scrubber.scrub(header.joined(separator: "\n") + "\n" + body)
    }
}

/// Hides the home folder and the account's names in exported logs.
public struct LogScrubber: Sendable {
    public static let placeholder = "<user>"

    private let homeDirectory: String
    private let names: [String]

    /// `names` are the account's short name and full name; names shorter than two characters are left alone so that
    /// a one-letter name doesn't blank out every word with that letter on its own.
    public init(homeDirectory: String, names: [String]) {
        self.homeDirectory = homeDirectory.hasSuffix("/") ? String(homeDirectory.dropLast()) : homeDirectory
        // Longest first, so "Simon Goo" is replaced as a whole before "Simon" is.
        self.names = Array(Set(names.map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count >= 2 })).sorted { $0.count > $1.count }
    }

    public func scrub(_ text: String) -> String {
        var result = text
        if !homeDirectory.isEmpty {
            result = result.replacingOccurrences(of: homeDirectory, with: "~")
        }
        for name in names {
            // Whole words only, ignoring case: "goo" hides "Goo" in a path but leaves "google" alone.
            let pattern = "(?<![\\p{L}\\p{N}_])" + NSRegularExpression.escapedPattern(for: name) + "(?![\\p{L}\\p{N}_])"
            guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            result = expression.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: NSRegularExpression.escapedTemplate(for: Self.placeholder))
        }
        return result
    }
}
