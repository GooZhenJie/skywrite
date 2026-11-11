import SwiftUI

/// Exporting logs, kept off General so it doesn't sit among the everyday settings (user decision 2026-11-11).
/// Docker Desktop has a Troubleshoot screen of its own; Karabiner-Elements gives its log a page of its own.
struct TroubleshootingSettingsPane: View {
    @EnvironmentObject private var model: SettingsModel

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    HStack(spacing: 8) {
                        if model.isCollectingLogs {
                            ProgressView()
                                .controlSize(.small)
                            Text("Collecting logs…").font(.callout).foregroundStyle(.secondary)
                        }
                        Button("Export Logs…") {
                            model.exportLogs()
                        }
                        .disabled(model.isCollectingLogs)
                    }
                } label: {
                    Text("Logs")
                    Text("If Skywrite misbehaves, export this file and send it to the developer.").font(.callout)
                }
            } footer: {
                Text("The file lists what Skywrite did, such as notes opening and closing, and which app was in front (for example com.google.Chrome). It never includes what you wrote in a note, and your home folder and user name are hidden.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
