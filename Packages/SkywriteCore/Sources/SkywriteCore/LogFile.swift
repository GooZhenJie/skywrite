import Foundation

/// A log file that never grows past twice `maximumSize`: when the current file would go over it, the current file becomes
/// the previous file and a new one starts. Writes happen in order on a queue of their own, so logging never waits for the
/// disk. The app keeps one in ~/Library/Logs/Skywrite (see `LogFile.shared` in the app).
public final class LogFile: @unchecked Sendable {
    /// Chosen by the user on 2026-11-07, following the Claude desktop app on the developer's Mac, which starts a new log
    /// file at 10 MiB (main1.log to main4.log were each 10,486,xxx bytes). At the developer's rate that day, about 530 KB
    /// in 19 hours of heavy testing, one file holds about two weeks, so an export keeps whatever went wrong days ago.
    public static let standardMaximumSize: UInt64 = 10 * 1024 * 1024

    public let currentURL: URL
    public let previousURL: URL
    private let maximumSize: UInt64
    private let processIdentifier: Int32
    private let formatter: DateFormatter
    private let queue = DispatchQueue(label: "io.github.goozhenjie.skywrite.log-file")
    private var handle: FileHandle?
    private var size: UInt64 = 0

    public init(
        folder: URL,
        maximumSize: UInt64 = LogFile.standardMaximumSize,
        timeZone: TimeZone = .current,
        processIdentifier: Int32 = ProcessInfo.processInfo.processIdentifier
    ) {
        currentURL = folder.appending(path: "Skywrite.log")
        previousURL = folder.appending(path: "Skywrite.previous.log")
        self.maximumSize = maximumSize
        self.processIdentifier = processIdentifier
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS xx"
        self.formatter = formatter
    }

    public func append(category: String, level: String?, message: String, date: Date = Date()) {
        queue.async { [self] in
            let source = level.map { "\(category) \($0)" } ?? category
            let line = "\(formatter.string(from: date)) [\(processIdentifier)] \(source): \(message)\n"
            write(Data(line.utf8))
        }
    }

    /// The previous file followed by the current one, oldest line first. Waits for the lines already appended.
    public func contents() -> String {
        queue.sync {
            [previousURL, currentURL].compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined()
        }
    }

    private func write(_ data: Data) {
        if handle == nil {
            openCurrentFile()
        }
        if size + UInt64(data.count) > maximumSize {
            startNewFile()
        }
        guard let handle else { return }
        do {
            try handle.write(contentsOf: data)
            size += UInt64(data.count)
        } catch {
            self.handle = nil
        }
    }

    private func openCurrentFile() {
        let manager = FileManager.default
        try? manager.createDirectory(at: currentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !manager.fileExists(atPath: currentURL.path) {
            manager.createFile(atPath: currentURL.path, contents: nil)
        }
        handle = try? FileHandle(forWritingTo: currentURL)
        size = (try? handle?.seekToEnd()) ?? 0
    }

    private func startNewFile() {
        try? handle?.close()
        handle = nil
        let manager = FileManager.default
        try? manager.removeItem(at: previousURL)
        try? manager.moveItem(at: currentURL, to: previousURL)
        openCurrentFile()
    }
}
