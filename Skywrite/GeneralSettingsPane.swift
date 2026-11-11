import SkywriteCore
import SwiftUI

struct GeneralSettingsPane: View {
    @EnvironmentObject private var model: SettingsModel
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var updater: SoftwareUpdater

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $preferences.showsInDock) {
                    Text(verbatim: "Dock")
                    Text("Right-click the Dock icon for recent notes").font(.callout)
                }
                .accessibilityIdentifier("show-in-dock")
                Toggle(isOn: $preferences.showsInMenuBar) {
                    Text("Menu bar")
                    Text("Click the icon for new note, recent notes and settings").font(.callout)
                }
                .accessibilityIdentifier("show-in-menu-bar")
            } header: {
                Text("Show Skywrite In")
            } footer: {
                if !preferences.showsInDock && !preferences.showsInMenuBar {
                    Text("Skywrite won’t appear in the Dock or the menu bar. To get back here, open Skywrite again from Finder or Spotlight.")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }
            Section("Startup") {
                Toggle("Open at login", isOn: Binding(get: { model.opensAtLogin }, set: { model.setOpensAtLogin($0) }))
            }
            // Laid out like Maccy's and Rectangle's update settings: a switch for automatic checks and a button to check now.
            Section("Updates") {
                Toggle(isOn: Binding(get: { updater.automaticallyChecksForUpdates }, set: { updater.setAutomaticallyChecksForUpdates($0) })) {
                    Text("Check for updates automatically")
                    Text("Once a day, Skywrite asks GitHub whether there’s a newer version. Your notes never leave your Mac.").font(.callout)
                }
                .accessibilityIdentifier("check-for-updates-automatically")
                LabeledContent {
                    CheckForUpdatesButton(updater: updater)
                } label: {
                    Text(AboutSettingsPane.version)
                }
            }
            Section("Settings Window") {
                Toggle(isOn: $preferences.closesSettingsWhenInactive) {
                    Text("Close this window when you switch to another app")
                    Text("Only the window closes. Skywrite and your notes keep running, and your changes are already saved.").font(.callout)
                }
                .accessibilityIdentifier("close-settings-when-inactive")
            }
        }
        .formStyle(.grouped)
    }
}
