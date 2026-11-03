import AppKit
import Carbon.HIToolbox
import SkywriteCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    static let isUITesting = CommandLine.arguments.contains("--ui-testing")

    private var noteManager: NoteManager?
    private var placementController: PlacementController?
    private var tapMonitor: ModifierTapMonitor?
    private let hotkeys = GlobalHotkeys()
    private let accessibility = AccessibilityPermission()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let manager = NoteManager(store: Self.isUITesting ? Self.uiTestingStore() : NoteStore.standard(bundleIdentifier: Bundle.main.bundleIdentifier ?? "io.github.goozhenjie.skywrite"))
        noteManager = manager
        placementController = PlacementController { [weak manager] placement in
            manager?.createNote(from: placement)
        }
        NSApp.mainMenu = MainMenu.build(appDelegate: self)
        if !Self.isUITesting {
            startGlobalInput()
        }
        manager.restoreNotes()
    }

    private static func uiTestingStore() -> NoteStore {
        let folder = FileManager.default.temporaryDirectory.appending(path: "Skywrite-UITests-\(UUID().uuidString)")
        return NoteStore(notesFolder: folder.appending(path: "notes"), recordURL: folder.appending(path: "notes.json"))
    }

    private func startGlobalInput() {
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
