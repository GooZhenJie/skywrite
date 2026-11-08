import AppKit
import os

enum EventLog {
    nonisolated static let subsystem = Bundle.main.bundleIdentifier ?? "io.github.goozhenjie.skywrite"

    nonisolated static let app = EventLogger(category: "app")
    nonisolated static let input = EventLogger(category: "input")
    nonisolated static let notes = EventLogger(category: "notes")
    nonisolated static let windows = EventLogger(category: "windows")
    nonisolated static let settings = EventLogger(category: "settings")

    static func describe(_ window: NSWindow?) -> String {
        guard let window else { return "none" }
        let name = window.identifier?.rawValue ?? String(describing: type(of: window))
        return "\(name) visible=\(window.isVisible) key=\(window.isKeyWindow) onActiveSpace=\(window.isOnActiveSpace) level=\(window.level.rawValue) behavior=\(window.collectionBehavior.rawValue)"
    }

    static var activationPolicyName: String {
        switch NSApp.activationPolicy() {
        case .regular: "regular"
        case .accessory: "accessory"
        case .prohibited: "prohibited"
        @unknown default: "unknown"
        }
    }
}

final class EventRecorder {
    private var observers: [NSObjectProtocol] = []

    func start() {
        let center = NotificationCenter.default
        let appEvents: [Notification.Name] = [
            NSApplication.didBecomeActiveNotification,
            NSApplication.didResignActiveNotification,
            NSApplication.didHideNotification,
            NSApplication.didUnhideNotification,
            NSApplication.didChangeScreenParametersNotification
        ]
        for name in appEvents {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { notification in
                let name = notification.name.rawValue
                MainActor.assumeIsolated {
                    EventLog.app.notice("\(name, privacy: .public) policy=\(EventLog.activationPolicyName, privacy: .public) keyWindow=\(EventLog.describe(NSApp.keyWindow), privacy: .public)")
                }
            })
        }
        let windowEvents: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.willCloseNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
            NSWindow.didChangeOcclusionStateNotification
        ]
        for name in windowEvents {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { notification in
                let name = notification.name.rawValue
                let object = notification.object as? NSWindow
                MainActor.assumeIsolated {
                    guard let window = object, window.identifier != nil else { return }
                    EventLog.windows.notice("\(name, privacy: .public) \(EventLog.describe(window), privacy: .public)")
                }
            })
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                let notes = NSApp.windows.filter { $0.identifier?.rawValue.hasPrefix("note-") == true }
                EventLog.windows.notice("activeSpaceDidChange notes=\(notes.count, privacy: .public)")
                for window in notes {
                    EventLog.windows.notice("  \(EventLog.describe(window), privacy: .public)")
                }
            }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleIdentifier = application?.bundleIdentifier ?? "unknown"
            MainActor.assumeIsolated {
                EventLog.app.notice("frontmost app changed to \(bundleIdentifier, privacy: .public)")
            }
        })
    }
}
