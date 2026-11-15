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
    /// Windows that can be the main window stay off screen until Skywrite stops being the active app, then go back to
    /// the back. Only those: notes, the placement layer and the menu bar's own status bar windows stay untouched.
    func activateLeavingWindowsBehind() {
        guard !isActive else { return }
        WindowsKeptOffScreen.hold(windows.filter { $0.isVisible && $0.canBecomeMain })
        if !activateFromFrontmostApp() {
            WindowsKeptOffScreen.putBack()
        }
    }

    /// Closing the note you were typing in, when Skywrite came to the front for it: goes back to the app you came from,
    /// with the settings window kept off screen until that app is in front, so AppKit has no settings window to make key
    /// and bring forward in between. When you were already in Skywrite, in the settings window say, you stay there.
    func leaveClosingNote() {
        guard let previous = PreviousApp.toGoBackTo else {
            EventLog.app.notice("note closed, staying in Skywrite")
            return
        }
        WindowsKeptOffScreen.hold(windows.filter { $0.isVisible && $0.canBecomeMain })
        if !PreviousApp.handBack(to: previous) {
            WindowsKeptOffScreen.putBack()
        }
    }
}

/// The app that was in front before Skywrite, so closing the note you were typing in can go back to it.
///
/// Closing that note left Skywrite active with no note to make key, and AppKit made the settings window key and
/// brought it forward. Tracked for every app that comes to the front, not only when Skywrite activates itself:
/// clicking a note brings Skywrite forward before any of its code runs, so remembering it there missed that app.
///
/// Only used when Skywrite came to the front for a note. Going back regardless sent you out of the settings window to
/// the last app you had used when you made a note there and closed it (found 2026-11-15).
enum PreviousApp {
    private static var app: NSRunningApplication?
    private static var cameForwardForNote = false
    private static var isDeciding = false
    private static var observers: [NSObjectProtocol] = []

    static func startTracking() {
        guard observers.isEmpty else { return }
        if let frontmost = NSWorkspace.shared.frontmostApplication, frontmost != .current {
            app = frontmost
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { notification in
            let activated = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let processIdentifier = activated?.processIdentifier
            MainActor.assumeIsolated {
                guard let processIdentifier, processIdentifier != NSRunningApplication.current.processIdentifier else { return }
                app = NSRunningApplication(processIdentifier: processIdentifier)
            }
        })
        // Skywrite came forward for a note when the first window to become key as it comes forward is a note or the
        // placement layer: pressing twice, a shortcut, or clicking a note in another app. Opening the settings window,
        // from the Dock, the menu bar or ⌘-Tab, makes that one key instead. The order varies, so either signal decides:
        // clicking a note posted didBecomeActive with no key window and the note became key 2 ms later (log 2026-11-15
        // 18:39:14), while Settings… from the menu bar made the window key before didBecomeActive (log 2026-11-13 07:57:24).
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.willBecomeActiveNotification, object: NSApp, queue: .main) { _ in
            MainActor.assumeIsolated {
                cameForwardForNote = false
                isDeciding = true
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: NSApp, queue: .main) { _ in
            MainActor.assumeIsolated {
                guard isDeciding, let key = NSApp.keyWindow else { return }
                decide(by: key)
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { notification in
            let window = notification.object as? NSWindow
            MainActor.assumeIsolated {
                guard let window else { return }
                if isDeciding {
                    decide(by: window)
                } else if window.canBecomeMain {
                    // Going to the settings window later in the same visit ends it: you're in Skywrite now.
                    cameForwardForNote = false
                }
            }
        })
    }

    private static func decide(by keyWindow: NSWindow) {
        isDeciding = false
        cameForwardForNote = keyWindow is NotePanel || keyWindow is PlacementPanel
        EventLog.app.notice("in front for a note=\(cameForwardForNote, privacy: .public) first key window=\(EventLog.describe(keyWindow), privacy: .public)")
    }

    /// The app to go back to when the note you were typing in closes, or nil to stay in Skywrite.
    static var toGoBackTo: NSRunningApplication? {
        guard NSApp.isActive, cameForwardForNote, let app, !app.isTerminated else { return nil }
        return app
    }

    /// Gives the front back to `previous` while Skywrite is still active. Returns whether macOS accepted it.
    @discardableResult
    static func handBack(to previous: NSRunningApplication) -> Bool {
        NSApp.yieldActivation(to: previous)
        let accepted = previous.activate(from: .current, options: [])
        EventLog.app.notice("front back to \(previous.bundleIdentifier ?? "unknown", privacy: .public) accepted=\(accepted, privacy: .public)")
        return accepted
    }
}

/// Windows taken off screen while Skywrite is in front for a note, put back at the back of the screen once another
/// app is in front. Snow Shot 1.5.4 does the same for its main window during a capture (mg-chao/snow-shot#2496).
///
/// Putting them back as soon as Skywrite was active, as before, let the settings window come forward again later in
/// the same visit, when the note you were typing in closed. A window shown again in the meantime (Settings… from the
/// menu bar), minimized or closed is left alone.
enum WindowsKeptOffScreen {
    private static var windows: [NSWindow] = []
    private static var observers: [NSObjectProtocol] = []

    static func hold(_ candidates: [NSWindow]) {
        let added = candidates.filter { candidate in !windows.contains { $0 === candidate } }
        guard !added.isEmpty else { return }
        added.forEach { $0.orderOut(nil) }
        windows += added
        EventLog.windows.notice("windows kept off screen until another app is in front: \(added.map(EventLog.describe).joined(separator: ", "), privacy: .public)")
        startObserving()
    }

    static func putBack() {
        stopObserving()
        let returning = windows.filter { !$0.isVisible && !$0.isMiniaturized }
        windows = []
        returning.forEach { $0.orderBack(nil) }
        if !returning.isEmpty {
            EventLog.windows.notice("windows put back behind: \(returning.map(EventLog.describe).joined(separator: ", "), privacy: .public)")
        }
    }

    private static func startObserving() {
        guard observers.isEmpty else { return }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: NSApp, queue: .main) { _ in
            MainActor.assumeIsolated {
                putBack()
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { notification in
            let closing = (notification.object as AnyObject?).map(ObjectIdentifier.init)
            MainActor.assumeIsolated {
                windows.removeAll { ObjectIdentifier($0) == closing }
            }
        })
    }

    private static func stopObserving() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }
}
