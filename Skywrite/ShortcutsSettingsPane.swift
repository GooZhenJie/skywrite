import ApplicationServices
import SkywriteCore
import SwiftUI

struct ShortcutsSettingsPane: View {
    @EnvironmentObject private var model: SettingsModel
    @EnvironmentObject private var preferences: Preferences
    @State private var accessibilityTrusted = AXIsProcessTrusted()

    var body: some View {
        Form {
            Section {
                Picker(selection: $preferences.tapKey) {
                    ForEach(TapKey.allCases, id: \.self) { key in
                        Text(key.title).tag(key)
                    }
                } label: {
                    Text("New note: press twice")
                    Text(tapKeyNote)
                        .font(.callout)
                }
                if preferences.tapKey != .off && !accessibilityTrusted {
                    LabeledContent {
                        Button("Open System Settings", action: openAccessibilitySettings)
                    } label: {
                        Text("Waiting for Accessibility permission")
                        Text("Turn on Skywrite in Privacy & Security > Accessibility.")
                            .font(.callout)
                    }
                }
                ForEach(ShortcutAction.allCases, id: \.self) { action in
                    LabeledContent(action.title) {
                        ShortcutRecorder(action: action)
                    }
                }
            } header: {
                Text("Global Shortcuts")
            } footer: {
                HStack {
                    Spacer()
                    Button("Restore Defaults") {
                        preferences.restoreDefaultShortcuts()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task {
            // Notices the permission being turned on in System Settings while this pane is open, as often as Rectangle
            // checks in its own permission window (every 0.3 s).
            while !Task.isCancelled {
                accessibilityTrusted = AXIsProcessTrusted()
                try? await Task.sleep(for: .seconds(0.3))
            }
        }
    }

    private var tapKeyNote: String {
        switch preferences.tapKey {
        case .off: String(localized: "Choose a key, then press it twice to make a note. Skywrite will ask for Accessibility permission so it can notice the key in other apps.")
        case .rightCommand: String(localized: "If Dictation is also set to Press Right Command Key Twice, both will start.")
        case .eitherOption, .rightOption: String(localized: "Then click where the note should go.")
        }
    }

    /// The same Privacy & Security pane Rectangle opens from its permission window.
    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}

extension TapKey {
    var title: String {
        switch self {
        case .off: String(localized: "Off")
        case .rightOption: String(localized: "Right ⌥")
        case .rightCommand: String(localized: "Right ⌘")
        case .eitherOption: String(localized: "Either ⌥")
        }
    }
}

extension ShortcutAction {
    var title: String {
        switch self {
        case .newNote: String(localized: "New note")
        case .toggleAllNotes: String(localized: "Show or hide all notes")
        case .reopenClosedNote: String(localized: "Reopen closed note")
        }
    }
}

struct ShortcutRecorder: View {
    let action: ShortcutAction
    @EnvironmentObject private var model: SettingsModel
    @EnvironmentObject private var preferences: Preferences
    @State private var monitor: Any?

    private var isRecording: Bool {
        model.recordingAction == action
    }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                isRecording ? stop() : start()
            } label: {
                if isRecording {
                    Text("Type shortcut…").foregroundStyle(.secondary)
                } else if let shortcut = preferences.shortcut(for: action) {
                    HStack(spacing: 3) {
                        ForEach(Array(shortcut.symbols.enumerated()), id: \.offset) { _, symbol in
                            Text(symbol)
                                .font(.system(size: 12, weight: .medium))
                                .frame(minWidth: 19, minHeight: 18)
                                .padding(.horizontal, 3)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }
                    }
                } else {
                    Text("Record Shortcut").foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            if preferences.shortcut(for: action) != nil, !isRecording {
                Button {
                    preferences.shortcuts[action] = .some(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Clear shortcut"))
            }
        }
        .onDisappear(perform: stop)
        .onChange(of: model.recordingAction) { _, recording in
            if recording != action {
                removeMonitor()
            }
        }
    }

    private func start() {
        model.recordingAction = action
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil
        }
    }

    private func handle(_ event: NSEvent) {
        switch Int(event.keyCode) {
        case 0x35:
            stop()
        case 0x33, 0x75:
            preferences.shortcuts[action] = .some(nil)
            stop()
        default:
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var carbon: UInt32 = 0
            if flags.contains(.control) { carbon |= Shortcut.controlFlag }
            if flags.contains(.option) { carbon |= Shortcut.optionFlag }
            if flags.contains(.shift) { carbon |= Shortcut.shiftFlag }
            if flags.contains(.command) { carbon |= Shortcut.commandFlag }
            let label = event.charactersIgnoringModifiers?.uppercased() ?? ""
            let shortcut = Shortcut(keyCode: UInt32(event.keyCode), carbonModifiers: carbon, keyLabel: label)
            guard shortcut.hasModifier, !label.isEmpty else {
                NSSound.beep()
                return
            }
            preferences.shortcuts[action] = .some(shortcut)
            stop()
        }
    }

    private func stop() {
        removeMonitor()
        if model.recordingAction == action {
            model.recordingAction = nil
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
