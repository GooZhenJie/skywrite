import AppKit
import Combine
import Sparkle
import SwiftUI

/// Looks for new versions of Skywrite with Sparkle (https://sparkle-project.org), the open-source updater Maccy and
/// Rectangle also use. Sparkle reads the list of versions at SUFeedURL in Info.plist (appcast.xml on the main branch) and
/// only installs an update signed with the private key that matches SUPublicEDKey, so a changed list or download can't
/// slip in someone else's app.
///
/// Checks start turned off: on the second launch Sparkle asks whether to check automatically, its default when
/// SUEnableAutomaticChecks isn't set (user decision 2026-11-07). The answer can be changed in General settings. Once
/// turned on, Sparkle checks once a day, its default SUScheduledCheckInterval of 86400 seconds.
///
/// Skywrite lives in the menu bar, so an update found in the background doesn't pop up over what you're doing. As in
/// Rectangle, "Check for Updates…" turns into "Update Available…" until you open it (Sparkle's gentle reminders,
/// https://sparkle-project.org/documentation/gentle-reminders/, read 2026-11-08).
final class SoftwareUpdater: NSObject, ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var hasWaitingUpdate = false
    private var controller: SPUStandardUpdaterController?

    /// UI tests don't start the updater, so they never go online or see Sparkle's question.
    init(starts: Bool) {
        super.init()
        let controller = SPUStandardUpdaterController(startingUpdater: starts, updaterDelegate: nil, userDriverDelegate: self)
        self.controller = controller
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates).assign(to: &$automaticallyChecksForUpdates)
    }

    /// What "Check for Updates…" in the menu bar menu, the app menu and General settings does. When an update is already
    /// waiting, Sparkle brings its window back instead of checking again.
    @objc func checkForUpdates(_ sender: Any?) {
        EventLog.app.notice("check for updates waiting=\(self.hasWaitingUpdate, privacy: .public)")
        NSApp.activateFromFrontmostApp()
        controller?.checkForUpdates(sender)
    }

    /// Only called when you flip the switch. Sparkle asks apps not to set this at other times, since that would override
    /// your answer and restart its schedule.
    func setAutomaticallyChecksForUpdates(_ checks: Bool) {
        EventLog.app.notice("preference automaticallyChecksForUpdates=\(checks, privacy: .public)")
        controller?.updater.automaticallyChecksForUpdates = checks
    }
}

extension SoftwareUpdater: NSMenuItemValidation {
    /// The menu items read "Update Available…" while an update found in the background waits, as in Rectangle.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(checkForUpdates(_:)) {
            menuItem.title = hasWaitingUpdate ? String(localized: "Update Available…") : String(localized: "Check for Updates…")
        }
        return canCheckForUpdates
    }
}

extension SoftwareUpdater: SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool {
        true
    }

    /// Right after launch Sparkle may show the update itself; any other time it waits for you to open it from a menu.
    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        EventLog.app.notice("update found version=\(update.displayVersionString, privacy: .public) immediateFocus=\(immediateFocus, privacy: .public)")
        if immediateFocus {
            return true
        }
        hasWaitingUpdate = true
        return false
    }

    func standardUserDriverWillFinishUpdateSession() {
        hasWaitingUpdate = false
    }
}

/// The "Check for Updates…" button in General and About settings. It reads "Update Available…" while an update found in
/// the background waits, like the menu items.
struct CheckForUpdatesButton: View {
    @ObservedObject var updater: SoftwareUpdater

    var body: some View {
        Button {
            updater.checkForUpdates(nil)
        } label: {
            if updater.hasWaitingUpdate {
                Text("Update Available…")
            } else {
                Text("Check for Updates…")
            }
        }
        .disabled(!updater.canCheckForUpdates)
    }
}
