import SkywriteCore
import SwiftUI

struct GeneralSettingsPane: View {
    @EnvironmentObject private var model: SettingsModel
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var updater: SoftwareUpdater

    var body: some View {
        Form {
            Section {
                // No second line under these two, as on Rectangle's and Ice's menu bar icon switches: they only say how
                // to get back once the icon is gone, which the footer below does.
                Toggle("Menu bar", isOn: $preferences.showsInMenuBar)
                    .accessibilityIdentifier("show-in-menu-bar")
                Toggle(isOn: $preferences.showsInDock) {
                    Text(verbatim: "Dock")
                }
                .accessibilityIdentifier("show-in-dock")
            } header: {
                Text("Show Skywrite In")
            } footer: {
                if !preferences.showsInDock && !preferences.showsInMenuBar {
                    // Only how to get back, like Rectangle's "When the menu bar icon is hidden, relaunch Rectangle from Finder to open".
                    Text("To get back here, open Skywrite again from Finder or Spotlight.")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }
            Section("Startup") {
                Toggle("Open at login", isOn: Binding(get: { model.opensAtLogin }, set: { model.setOpensAtLogin($0) }))
            }
            // Laid out like Maccy's and Rectangle's update settings: a switch for automatic checks and a button to check now.
            Section("Updates") {
                Toggle("Check for updates automatically", isOn: Binding(get: { updater.automaticallyChecksForUpdates }, set: { updater.setAutomaticallyChecksForUpdates($0) }))
                    .accessibilityIdentifier("check-for-updates-automatically")
                LabeledContent {
                    CheckForUpdatesButton(updater: updater)
                } label: {
                    Text(AboutSettingsPane.version)
                }
            }
        }
        .formStyle(.grouped)
    }
}
