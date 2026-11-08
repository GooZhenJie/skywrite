import AppKit
import SkywriteCore
import UniformTypeIdentifiers

/// Turns Skywrite's own log file into a text file you can send the developer when something goes wrong.
/// See `LogFile` for where the log lives and how much of it is kept.
nonisolated enum LogExporter {
    static func collect() -> LogReport {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return LogReport(
            log: LogFile.shared.contents(),
            appVersion: "\(version) (\(build))",
            systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            exportedAt: Date()
        )
    }

    static var scrubber: LogScrubber {
        LogScrubber(homeDirectory: NSHomeDirectory(), names: [NSUserName(), NSFullUserName()])
    }

    static var suggestedFileName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HHmm"
        return "Skywrite Logs \(formatter.string(from: Date())).txt"
    }

    /// Asks where to save the file, writes it and shows it in its folder. Returns false when you cancel.
    @MainActor
    static func save(_ text: String, attachedTo window: NSWindow?) async throws -> Bool {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFileName
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        let response = if let window {
            await panel.beginSheetModal(for: window)
        } else {
            await withCheckedContinuation { continuation in
                panel.begin { continuation.resume(returning: $0) }
            }
        }
        guard response == .OK, let url = panel.url else { return false }
        try text.write(to: url, atomically: true, encoding: .utf8)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        return true
    }
}
