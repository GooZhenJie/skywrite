import Foundation
import os
import SkywriteCore

/// Writes each event both to the system log (for Console and `log show`) and to Skywrite's own log file, which is what
/// Export Logs… copies. Reading Skywrite's lines back out of the system log took 7 to 14 s on the developer's Mac and
/// only worked on administrator accounts; the file is read at once on any account.
///
/// Messages are written the same way as with `os.Logger` (`"moved \(count, privacy: .public)"`), so the call sites
/// didn't change. A value not marked `.public` is written as `<private>` in both places, as the system log does.
nonisolated struct EventLogger: Sendable {
    private let logger: Logger
    private let category: String

    init(category: String) {
        logger = Logger(subsystem: EventLog.subsystem, category: category)
        self.category = category
    }

    func notice(_ message: LogMessage) {
        logger.notice("\(message.text, privacy: .public)")
        LogFile.shared.append(category: category, level: nil, message: message.text)
    }

    func error(_ message: LogMessage) {
        logger.error("\(message.text, privacy: .public)")
        LogFile.shared.append(category: category, level: "error", message: message.text)
    }
}

nonisolated enum LogPrivacy: Sendable {
    case `public`
    case `private`
}

nonisolated enum LogFloatFormat: Sendable {
    case fixed(precision: Int)
}

nonisolated struct LogMessage: ExpressibleByStringInterpolation, Sendable {
    let text: String

    init(stringLiteral value: String) {
        text = value
    }

    init(stringInterpolation: StringInterpolation) {
        text = stringInterpolation.text
    }

    struct StringInterpolation: StringInterpolationProtocol {
        var text = ""

        init(literalCapacity: Int, interpolationCount: Int) {
            text.reserveCapacity(literalCapacity + interpolationCount * 8)
        }

        mutating func appendLiteral(_ literal: String) {
            text += literal
        }

        mutating func appendInterpolation<Value>(_ value: Value, privacy: LogPrivacy = .private) {
            text += privacy == .public ? String(describing: value) : "<private>"
        }

        mutating func appendInterpolation<Value: BinaryFloatingPoint>(_ value: Value, format: LogFloatFormat, privacy: LogPrivacy = .private) {
            guard privacy == .public else {
                text += "<private>"
                return
            }
            switch format {
            case .fixed(let precision): text += String(format: "%.\(precision)f", Double(value))
            }
        }
    }
}

extension LogFile {
    /// Skywrite's own log file in ~/Library/Logs/Skywrite, where Mac apps keep their logs (Claude, Raycast and Notion all
    /// have a folder there on the developer's Mac). See `LogFile` in SkywriteCore for how much of it is kept.
    nonisolated static let shared = LogFile(folder: standardFolder())

    /// UI tests write to a folder of their own, so test runs never end up in the log you'd send.
    nonisolated private static func standardFolder() -> URL {
        if CommandLine.arguments.contains("--ui-testing") {
            return FileManager.default.temporaryDirectory.appending(path: "Skywrite-UITests-Logs-\(ProcessInfo.processInfo.processIdentifier)")
        }
        return FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Logs/Skywrite")
    }
}
