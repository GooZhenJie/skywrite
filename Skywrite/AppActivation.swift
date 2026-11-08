import AppKit

extension NSApplication {
    /// Brings Skywrite to the front so its windows take keyboard input. Returns whether macOS accepted it.
    ///
    /// `activate()` only asks, and macOS can turn the request down while another app is in front: picking Settings…
    /// from the menu bar menu opened the window behind that app. Taking over from the frontmost app goes through.
    /// Measured 2026-11-06 on macOS 27.2 with a small menu-bar-only app: after a menu item was picked, `activate()`
    /// left the other app in front while `activate(from:)` brought the app forward, and `activate(from:)` also worked
    /// with no menu and no user action at all.
    @discardableResult
    func activateFromFrontmostApp() -> Bool {
        let current = NSRunningApplication.current
        guard let frontmost = NSWorkspace.shared.frontmostApplication, frontmost != current else {
            activate()
            return true
        }
        let accepted = current.activate(from: frontmost, options: [])
        EventLog.app.notice("activate from \(frontmost.bundleIdentifier ?? "unknown", privacy: .public) accepted=\(accepted, privacy: .public)")
        return accepted
    }

    /// Brings Skywrite to the front for a note or for placing one, leaving an open settings window where it was.
    ///
    /// Activating an app brings its main window forward too (Apple's `activateAllWindows` documentation), and the
    /// settings window is Skywrite's main window whenever it's open, so it jumped in front of the app you were in.
    /// Windows that can be the main window come off screen while Skywrite activates and go back to the back once it
    /// has. Only those: notes, the placement layer and the menu bar's own status bar windows stay untouched.
    func activateLeavingWindowsBehind() {
        guard !isActive else { return }
        PreviousApp.remember(NSWorkspace.shared.frontmostApplication)
        let mainCapableWindows = windows.filter { $0.isVisible && $0.canBecomeMain }
        guard !mainCapableWindows.isEmpty else {
            activateFromFrontmostApp()
            return
        }
        let windowsLeftBehind = WindowsLeftBehind(mainCapableWindows)
        if activateFromFrontmostApp() {
            windowsLeftBehind.putBackOnceActive()
        } else {
            windowsLeftBehind.putBack()
        }
    }
}

/// The app that was in front when Skywrite last came forward for a note, so closing that note can go back to it.
///
/// Closing the note you were typing in left Skywrite active with no note to make key, and AppKit made the settings
/// window key and brought it forward. Forgotten as soon as Skywrite stops being the active app, so an old app never
/// gets the front back by surprise.
enum PreviousApp {
    private static var app: NSRunningApplication?
    private static var resignObserver: NSObjectProtocol?

    static func remember(_ frontmost: NSRunningApplication?) {
        guard let frontmost, frontmost != .current else { return }
        app = frontmost
        guard resignObserver == nil else { return }
        resignObserver = NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: NSApp, queue: .main) { _ in
            MainActor.assumeIsolated {
                app = nil
            }
        }
    }

    /// Gives the front back to that app while Skywrite is still active. Does nothing when there's none to go back to.
    static func handBack() {
        guard NSApp.isActive, let previous = app else { return }
        app = nil
        guard !previous.isTerminated else { return }
        NSApp.yieldActivation(to: previous)
        let accepted = previous.activate(from: .current, options: [])
        EventLog.app.notice("front back to \(previous.bundleIdentifier ?? "unknown", privacy: .public) accepted=\(accepted, privacy: .public)")
    }
}

/// Windows taken off screen while Skywrite activates, put back at the back of the screen once it's active.
private final class WindowsLeftBehind {
    private let windows: [NSWindow]
    private var activationObserver: NSObjectProtocol?

    init(_ windows: [NSWindow]) {
        self.windows = windows
        windows.forEach { $0.orderOut(nil) }
        EventLog.windows.notice("windows left behind while activating: \(windows.map(EventLog.describe).joined(separator: ", "), privacy: .public)")
    }

    func putBackOnceActive() {
        activationObserver = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: NSApp, queue: .main) { [self] _ in
            MainActor.assumeIsolated {
                putBack()
            }
        }
    }

    func putBack() {
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        windows.forEach { $0.orderBack(nil) }
    }
}
