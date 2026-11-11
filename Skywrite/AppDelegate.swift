import AppKit
import Combine
import SkywriteCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    static let isUITesting = CommandLine.arguments.contains("--ui-testing")

    private let preferences = Preferences(defaults: AppDelegate.isUITesting ? AppDelegate.uiTestingDefaults() : .standard)
    private var noteManager: NoteManager?
    private var placementController: PlacementController?
    private var tapMonitor: ModifierTapMonitor?
    private weak var openStatusMenu: NSMenu?
    private let hotkeys = GlobalHotkeys()
    private let accessibility = AccessibilityPermission()
    private let updater = SoftwareUpdater(starts: !AppDelegate.isUITesting)
    private var menus: AppMenus?
    private var statusItem: StatusItemController?
    private var settingsModel: SettingsModel?
    private var settingsWindow: SettingsWindowController?
    private var subscriptions: Set<AnyCancellable> = []
    private let eventRecorder = EventRecorder()
    private var dockSchedule = DockSwitchSchedule(applied: false)
    private var dockSwitchTask: Task<Void, Never>?
    private var retentionTimer: Timer?

    func applicationWillFinishLaunching(_ notification: Notification) {
        eventRecorder.start()
        EventLog.app.notice("login item status=\(LoginItem.statusName, privacy: .public)")
        EventLog.app.notice("launch version=\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "", privacy: .public) dock=\(self.preferences.showsInDock, privacy: .public) menuBar=\(self.preferences.showsInMenuBar, privacy: .public) tapKey=\(self.preferences.tapKey.rawValue, privacy: .public) accessibilityTrusted=\(AXIsProcessTrusted(), privacy: .public)")
        NSApp.setActivationPolicy(preferences.showsInDock ? .regular : .accessory)
        dockSchedule = DockSwitchSchedule(applied: preferences.showsInDock)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Self.isUITesting, let index = CommandLine.arguments.firstIndex(of: "--appearance"), index + 1 < CommandLine.arguments.count {
            NSApp.appearance = NSAppearance(named: CommandLine.arguments[index + 1] == "dark" ? .darkAqua : .aqua)
        }
        if Self.isUITesting {
            applyUITestingGlassArguments()
        }
        let manager = NoteManager(store: Self.isUITesting ? Self.uiTestingStore() : standardStore(), style: noteStyle())
        noteManager = manager
        placementController = PlacementController(lineHeight: { [weak manager] in
            manager?.style.lineHeight(zoom: 1) ?? 0
        }, padding: { [weak manager] in
            manager?.style.textPadding(zoom: 1) ?? .zero
        }, onPlace: { [weak manager] placement in
            manager?.createNote(from: placement)
        })
        NSApp.mainMenu = MainMenu.build(appDelegate: self, preferences: preferences, updater: updater)
        let menus = AppMenus(appDelegate: self, noteManager: manager, preferences: preferences, updater: updater)
        self.menus = menus
        statusItem = StatusItemController(menu: menus.makeStatusMenu()) { [weak self] in
            self?.preferences.showsInMenuBar = false
        }
        observePreferences()
        if !Self.isUITesting {
            startGlobalInput()
        }
        manager.restoreNotes()
        startRetentionChecks()
        if CommandLine.arguments.contains("--open-settings") {
            showSettings(nil)
        }
    }

    /// UI tests can start with a background already chosen: --glass-style softEdge|liquidGlass, --glass-strength 0...1.
    private func applyUITestingGlassArguments() {
        let arguments = CommandLine.arguments
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        if let style = value(after: "--glass-style").flatMap(GlassStyle.init) {
            preferences.glassStyle = style
        }
        if let strength = value(after: "--glass-strength").flatMap(Double.init) {
            preferences.glassStrength = strength
        }
    }

    private static func uiTestingStore() -> NoteStore {
        let folder = FileManager.default.temporaryDirectory.appending(path: "Skywrite-UITests-\(UUID().uuidString)")
        return NoteStore(notesFolder: folder.appending(path: "notes"), recordURL: folder.appending(path: "notes.json"))
    }

    private static func uiTestingDefaults() -> UserDefaults {
        UserDefaults(suiteName: "Skywrite-UITests-\(UUID().uuidString)") ?? .standard
    }

    private func standardStore() -> NoteStore {
        let standard = NoteStore.standard(bundleIdentifier: Bundle.main.bundleIdentifier ?? "io.github.goozhenjie.skywrite")
        guard let path = preferences.notesFolderPath else { return standard }
        return NoteStore(notesFolder: URL(fileURLWithPath: path, isDirectory: true), recordURL: standard.recordURL)
    }

    private func noteStyle() -> NoteStyle {
        NoteStyle(fontSize: preferences.fontSize, glassStyle: preferences.glassStyle, glassStrength: preferences.glassStrength, liquidGlassStaysClear: preferences.liquidGlassStaysClear)
    }

    private func observePreferences() {
        preferences.$showsInDock.removeDuplicates().sink { [weak self] shows in
            EventLog.settings.notice("preference showsInDock=\(shows, privacy: .public)")
            self?.requestDockVisibility(shows)
        }.store(in: &subscriptions)
        preferences.$showsInMenuBar.removeDuplicates().sink { [weak self] shows in
            self?.statusItem?.setVisible(shows)
        }.store(in: &subscriptions)
        Publishers.CombineLatest4(preferences.$fontSize, preferences.$glassStyle, preferences.$glassStrength, preferences.$liquidGlassStaysClear)
            .sink { [weak self] fontSize, glassStyle, glassStrength, staysClear in
                self?.noteManager?.style = NoteStyle(fontSize: fontSize, glassStyle: glassStyle, glassStrength: glassStrength, liquidGlassStaysClear: staysClear)
            }.store(in: &subscriptions)
        preferences.$noteRetention.dropFirst().removeDuplicates().sink { [weak self] retention in
            EventLog.settings.notice("preference noteRetentionDays=\(retention.rawValue, privacy: .public)")
            // Published fires before the stored value changes, so pass the new value along.
            self?.moveExpiredNotes(retention: retention)
        }.store(in: &subscriptions)
        preferences.$tapKey.dropFirst().removeDuplicates().sink { [weak self] key in
            EventLog.settings.notice("preference tapKey=\(key.rawValue, privacy: .public)")
            self?.startTapMonitor(key: key)
        }.store(in: &subscriptions)
        preferences.$shortcuts.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.shortcutsDidChange()
        }.store(in: &subscriptions)
        preferences.$closesSettingsWhenInactive.dropFirst().removeDuplicates().sink { closes in
            EventLog.settings.notice("preference closesSettingsWhenInactive=\(closes, privacy: .public)")
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification).sink { [weak self] _ in
            self?.closeSettingsIfAnotherAppCameForward()
        }.store(in: &subscriptions)
    }

    /// With "Close this window when you switch to another app" on, the settings window closes as soon as another app comes to the
    /// front, instead of staying open behind it. Settings apply as you change them, so closing loses nothing; the menu
    /// bar menu, the Dock icon or opening Skywrite again brings the window back. First tried 2026-11-06, when the
    /// window kept jumping in front of other apps; that was fixed another way, so this became an option, off by default.
    /// On by default since 2026-11-08 (see Preferences.closesSettingsWhenInactive).
    private func closeSettingsIfAnotherAppCameForward() {
        guard preferences.closesSettingsWhenInactive, let settingsWindow, settingsWindow.window?.isVisible == true else { return }
        EventLog.settings.notice("settings closed because another app came to the front")
        settingsWindow.close()
    }

    private func startGlobalInput() {
        registerHotkeys()
        startTapMonitor(key: preferences.tapKey)
    }

    /// Noticing a key pressed twice in other apps needs Accessibility permission, so Skywrite only watches for it, and only
    /// asks for the permission, while a key is chosen. With Off it needs no permission at all.
    private func startTapMonitor(key: TapKey) {
        // UI tests leave the tap off unless a test asks for it with --tap-monitor; --tap-interval widens the window.
        guard !Self.isUITesting || CommandLine.arguments.contains("--tap-monitor") else { return }
        tapMonitor?.stop()
        tapMonitor = nil
        guard key != .off else {
            accessibility.stopWaiting()
            return
        }
        let monitor = ModifierTapMonitor(key: key) { [weak self] in
            self?.doubleTapDetected()
        }
        if Self.isUITesting, let index = CommandLine.arguments.firstIndex(of: "--tap-interval"), index + 1 < CommandLine.arguments.count {
            monitor.intervalOverride = TimeInterval(CommandLine.arguments[index + 1])
        }
        tapMonitor = monitor
        monitor.start()
        accessibility.requestIfNeeded { [weak self] in
            self?.tapMonitor?.restart()
        }
    }

    /// With the menu bar menu open, the tap closes the menu first and starts the new note once it's gone.
    private func doubleTapDetected() {
        guard let openStatusMenu else {
            newNote(nil)
            return
        }
        openStatusMenu.cancelTracking()
        DispatchQueue.main.async { [weak self] in
            self?.newNote(nil)
        }
    }

    func statusMenuWillOpen(_ menu: NSMenu) {
        openStatusMenu = menu
        tapMonitor?.startWatchingDuringMenuTracking()
    }

    func statusMenuDidClose(_ menu: NSMenu) {
        openStatusMenu = nil
        tapMonitor?.stopWatchingDuringMenuTracking()
    }

    private func registerHotkeys() {
        hotkeys.unregisterAll()
        guard !Self.isUITesting, settingsModel?.recordingAction == nil else { return }
        for action in ShortcutAction.allCases {
            guard let shortcut = preferences.shortcut(for: action) else { continue }
            hotkeys.register(keyCode: shortcut.keyCode, modifiers: shortcut.carbonModifiers) { [weak self] in
                self?.perform(action)
            }
        }
    }

    private func shortcutsDidChange() {
        registerHotkeys()
        NSApp.mainMenu = MainMenu.build(appDelegate: self, preferences: preferences, updater: updater)
    }

    private func perform(_ action: ShortcutAction) {
        EventLog.input.notice("shortcut action \(action.rawValue, privacy: .public)")
        switch action {
        case .newNote: newNote(nil)
        case .toggleAllNotes: toggleAllNotes(nil)
        case .reopenClosedNote: reopenClosedNote(nil)
        }
    }

    private var isSettingsVisible: Bool {
        settingsWindow?.window?.isVisible ?? false
    }

    private func requestDockVisibility(_ shows: Bool) {
        guard let delay = dockSchedule.request(shows, now: ProcessInfo.processInfo.systemUptime) else { return }
        scheduleDockSwitch(after: delay)
    }

    private func scheduleDockSwitch(after delay: TimeInterval) {
        guard dockSwitchTask == nil else { return }
        if delay > 0 {
            EventLog.app.notice("dock switch held for \(delay, privacy: .public)s")
        }
        dockSwitchTask = Task { @MainActor [weak self] in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard let self else { return }
            self.dockSwitchTask = nil
            let now = ProcessInfo.processInfo.systemUptime
            if let shows = self.dockSchedule.fire(now: now) {
                self.applyDockVisibility(shows)
            } else if let remaining = self.dockSchedule.delay(now: now) {
                self.scheduleDockSwitch(after: remaining)
            }
        }
    }

    private func applyDockVisibility(_ shows: Bool) {
        let policy: NSApplication.ActivationPolicy = shows ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        let keepsSettingsInFront = isSettingsVisible && NSApp.isActive
        NSApp.setActivationPolicy(policy)
        EventLog.app.notice("activation policy set to \(EventLog.activationPolicyName, privacy: .public)")
        if keepsSettingsInFront {
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow?.window?.makeKeyAndOrderFront(nil)
        }
    }

    private func settingsDidClose() {
        settingsModel?.recordingAction = nil
    }

    func applicationWillTerminate(_ notification: Notification) {
        noteManager?.saveNow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        EventLog.app.notice("reopen hasVisibleWindows=\(flag, privacy: .public) opening settings")
        showSettings(nil)
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        menus?.makeDockMenu()
    }
}

// Menu commands, the settings window and the retention checks.
extension AppDelegate {
    @objc func newNote(_ sender: Any?) {
        EventLog.input.notice("new note requested sender=\(sender.map { String(describing: type(of: $0)) } ?? "shortcut", privacy: .public)")
        noteManager?.lockAll()
        placementController?.toggle()
    }

    @objc func reopenClosedNote(_ sender: Any?) {
        noteManager?.reopenLastClosed()
    }

    @objc func undo(_ sender: Any?) {
        reopenClosedNote(sender)
    }

    @objc func toggleAllNotes(_ sender: Any?) {
        noteManager?.toggleAllNotes()
    }

    @objc func moveNotesBackOnScreen(_ sender: Any?) {
        noteManager?.moveNotesBackOnScreen()
    }

    @objc func showRecentNote(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        noteManager?.showNote(id)
    }

    @objc func openNotesFolder(_ sender: Any?) {
        guard let folder = noteManager?.store.notesFolder else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }

    @objc func makeTextBigger(_ sender: Any?) {
        preferences.changeFontSize(by: NoteMetrics.fontSizeStep)
    }

    @objc func makeTextSmaller(_ sender: Any?) {
        preferences.changeFontSize(by: -NoteMetrics.fontSizeStep)
    }

    /// The standard About window, with the photographers to thank below the version, the way NetNewsWire and Tot list
    /// their credits there (both ship a Credits.rtf that this window shows).
    @objc func showAbout(_ sender: Any?) {
        NSApp.activateFromFrontmostApp()
        NSApp.orderFrontStandardAboutPanel(options: [.credits: PreviewBackdrop.creditsText()])
    }

    @objc func showSettings(_ sender: Any?) {
        EventLog.settings.notice("show settings sender=\(sender.map { String(describing: type(of: $0)) } ?? "none", privacy: .public)")
        guard let manager = noteManager else { return }
        let model = settingsModel ?? makeSettingsModel(manager: manager)
        model.noteCount = manager.noteCount
        model.notesFolder = manager.store.notesFolder
        model.opensAtLogin = LoginItem.isEnabled
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(model: model, preferences: preferences, updater: updater) { [weak self] in
                self?.settingsDidClose()
            }
        }
        settingsWindow?.present()
    }

    private func makeSettingsModel(manager: NoteManager) -> SettingsModel {
        let model = SettingsModel(notesFolder: manager.store.notesFolder, changeNotesFolder: { [weak self, weak manager] folder in
            try manager?.changeNotesFolder(to: folder)
            self?.preferences.notesFolderPath = folder.path
        }, expiredNoteCount: { [weak manager] retention in
            manager?.expiredNotes(for: retention).count ?? 0
        })
        model.uninstall = { [weak self, weak manager] in
            guard let manager else { return }
            AppUninstaller(noteManager: manager) { self?.settingsWindow?.close() }.run()
        }
        model.$recordingAction.dropFirst().removeDuplicates().sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.registerHotkeys()
            }
        }.store(in: &subscriptions)
        settingsModel = model
        return model
    }

    private func startRetentionChecks() {
        moveExpiredNotes(retention: preferences.noteRetention)
        // The timer runs on the main run loop, so its callback is already on the main actor.
        let timer = Timer(timeInterval: NoteMetrics.retentionCheckInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.moveExpiredNotes(retention: self.preferences.noteRetention)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        retentionTimer = timer
    }

    private func moveExpiredNotes(retention: NoteRetention) {
        guard let manager = noteManager else { return }
        manager.moveExpiredNotesToTrash(retention: retention)
        settingsModel?.noteCount = manager.noteCount
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(undo(_:)), #selector(reopenClosedNote(_:)):
            return noteManager?.canReopen ?? false
        case #selector(toggleAllNotes(_:)):
            return noteManager?.hasNotes ?? false
        default:
            return true
        }
    }
}
