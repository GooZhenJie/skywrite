import SwiftUI

/// Uninstalling gets a page of its own, as on Karabiner-Elements' settings, so it doesn't sit among the everyday
/// settings on General (user decision 2026-11-11).
struct UninstallSettingsPane: View {
    @EnvironmentObject private var model: SettingsModel

    var body: some View {
        Form {
            // Worded and coloured like Docker Desktop's Troubleshoot pane: "Uninstall Docker Desktop", one sentence, a red button.
            Section {
                LabeledContent {
                    // The pane's .tint(theme.accent) colours every button's text while the window is in front, so this one
                    // needs a red tint of its own; .foregroundStyle keeps it red while the window is in the background.
                    Button("Uninstall…", role: .destructive) {
                        model.uninstall?()
                    }
                    .foregroundStyle(.red)
                    .tint(.red)
                    .accessibilityIdentifier("uninstall-skywrite")
                } label: {
                    Text("Uninstall Skywrite")
                    Text("Removes Skywrite and all associated data from this Mac.").font(.callout)
                }
            }
        }
        .formStyle(.grouped)
    }
}
