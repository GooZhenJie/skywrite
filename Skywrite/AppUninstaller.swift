import AppKit
import ServiceManagement
import SkywriteCore

/// Uninstall Skywrite… on the General pane: asks first, then turns off Open at login, takes back the Accessibility
/// permission, clears the settings, moves the app and everything it saved to the Trash, and quits. Your notes stay
/// unless you tick the box. See `Uninstaller` in SkywriteCore for which folders go and why.
@MainActor
struct AppUninstaller {
    let noteManager: NoteManager
    let closeSettings: () -> Void

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "io.github.goozhenjie.skywrite"
    }

    func run() {
        let notesFolder = noteManager.store.notesFolder
        let noteFiles = Uninstaller.noteFileNames(known: noteManager.noteFileNames, in: notesFolder)
        guard let includesNotes = confirm(noteCount: noteFiles.count, notesFolder: notesFolder) else {
            EventLog.app.notice("uninstall cancelled")
            return
        }
        EventLog.app.notice("uninstall started includesNotes=\(includesNotes, privacy: .public) notes=\(noteFiles.count, privacy: .public)")
        // Windows close before the settings are cleared: closing the settings window saves its position as a setting.
        noteManager.stopSavingAndHideNotes()
        closeSettings()
        NSApp.windows.forEach { $0.orderOut(nil) }

        var leftBehind: [String] = []
        let uninstaller = Uninstaller()
        if !turnOffLoginItem() {
            leftBehind.append(String(localized: "Open at login: turn Skywrite off in System Settings › General › Login Items & Extensions."))
        }
        if !resetAccessibility() {
            leftBehind.append(AccessibilityPermissionText.whereToRemove)
        }
        if includesNotes {
            leftBehind += uninstaller.moveNotesToTrash(fileNames: noteFiles, in: notesFolder).map(\.displayPath)
        }
        let remainingSettings = uninstaller.clearPreferences(domain: bundleIdentifier)
        if !remainingSettings.isEmpty {
            leftBehind.append(String(localized: "Settings: run “defaults delete \(bundleIdentifier)” in Terminal."))
        }
        let locations = Uninstaller.Locations(home: FileManager.default.homeDirectoryForCurrentUser, bundleIdentifier: bundleIdentifier)
        // UI tests run a build that other tests still need, so they keep the app.
        let app = AppDelegate.isUITesting ? [] : [Bundle.main.bundleURL]
        // The logs go last so the steps above still get written down.
        EventLog.app.notice("uninstall moving files leftBehindSoFar=\(leftBehind.count, privacy: .public) remainingSettings=\(remainingSettings.count, privacy: .public)")
        leftBehind += uninstaller.moveToTrash(app + locations.all).map(\.displayPath)

        EventLog.app.notice("uninstall finished leftBehind=\(leftBehind.joined(separator: " | "), privacy: .public)")
        if !leftBehind.isEmpty {
            showLeftBehind(leftBehind)
        }
        // Not NSApp.terminate: that would save the notes and settings again on the way out.
        exit(0)
    }

    /// Returns nil when you cancel, otherwise whether your notes go to the Trash too.
    private func confirm(noteCount: Int, notesFolder: URL) -> Bool? {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "Uninstall Skywrite?")
        // One sentence, as Docker Desktop's "Uninstall Docker Desktop?" has; the notes are an opt-in box, as AnyDesk's
        // "Remove configuration files" is.
        alert.informativeText = String(localized: "This removes Skywrite and all associated data from this Mac.")
        if noteCount > 0 {
            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = String(localized: "Also move the \(noteCount) notes in \(notesFolder.displayPath) to the Trash")
            alert.suppressionButton?.state = .off
        }
        let uninstall = alert.addButton(withTitle: String(localized: "Uninstall"))
        uninstall.hasDestructiveAction = true
        alert.addButton(withTitle: String(localized: "Cancel"))
        NSApp.activateFromFrontmostApp()
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return alert.suppressionButton?.state == .on
    }

    private func showLeftBehind(_ items: [String]) {
        let alert = NSAlert()
        alert.messageText = String(localized: "Skywrite has been removed")
        alert.informativeText = String(localized: "Some items couldn’t be removed. You can remove them yourself:") + "\n\n" + items.joined(separator: "\n")
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }

    /// True when Skywrite no longer opens at login.
    private func turnOffLoginItem() -> Bool {
        guard !AppDelegate.isUITesting else { return true }
        let service = SMAppService.mainApp
        guard service.status == .enabled || service.status == .requiresApproval else { return true }
        do {
            try service.unregister()
            EventLog.app.notice("uninstall login item turned off")
            return true
        } catch {
            EventLog.app.error("uninstall login item failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Takes Skywrite off the Accessibility list in System Settings with `tccutil`, the command line tool macOS ships for
    /// resetting an app's privacy permissions. Only needed if Skywrite ever asked, which it does once a key is chosen for
    /// "New note: press twice". True when there was nothing to take back or it worked.
    private func resetAccessibility() -> Bool {
        guard !AppDelegate.isUITesting else { return true }
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", bundleIdentifier]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            EventLog.app.error("uninstall tccutil failed to start: \(error.localizedDescription, privacy: .public)")
            return !AXIsProcessTrusted()
        }
        EventLog.app.notice("uninstall tccutil exit=\(process.terminationStatus, privacy: .public)")
        return process.terminationStatus == 0 || !AXIsProcessTrusted()
    }
}

private extension URL {
    /// The path with your home folder shown as ~, the way Finder's Go to Folder takes it.
    var displayPath: String {
        (path as NSString).abbreviatingWithTildeInPath
    }
}
