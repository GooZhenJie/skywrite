import AppKit
import Carbon.HIToolbox
import SkywriteCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var noteManager: NoteManager?
    private var placementController: PlacementController?
    private var tapMonitor: ModifierTapMonitor?
    private let hotkeys = GlobalHotkeys()
    private let accessibility = AccessibilityPermission()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = NoteStore.standard(bundleIdentifier: Bundle.main.bundleIdentifier ?? "io.github.goozhenjie.skywrite")
        let manager = NoteManager(store: store)
        noteManager = manager
        placementController = PlacementController { [weak manager] placement in
            manager?.createNote(from: placement)
        }
        NSApp.mainMenu = MainMenu.build(appDelegate: self)
        hotkeys.register(keyCode: UInt32(kVK_ANSI_N), modifiers: UInt32(controlKey | optionKey)) { [weak self] in
            self?.newNote(nil)
        }
        hotkeys.register(keyCode: UInt32(kVK_ANSI_Z), modifiers: UInt32(controlKey | optionKey)) { [weak self] in
            self?.reopenClosedNote(nil)
        }
        let monitor = ModifierTapMonitor(key: .rightOption) { [weak self] in
            self?.newNote(nil)
        }
        tapMonitor = monitor
        monitor.start()
        accessibility.requestIfNeeded { [weak monitor] in
            monitor?.restart()
        }
        manager.restoreNotes()
    }

    func applicationWillTerminate(_ notification: Notification) {
        noteManager?.saveNow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc func newNote(_ sender: Any?) {
        noteManager?.lockAll()
        placementController?.toggle()
    }

    @objc func reopenClosedNote(_ sender: Any?) {
        noteManager?.reopenLastClosed()
    }

    @objc func undo(_ sender: Any?) {
        reopenClosedNote(sender)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(undo(_:)) || menuItem.action == #selector(reopenClosedNote(_:)) {
            return noteManager?.canReopen ?? false
        }
        return true
    }
}
