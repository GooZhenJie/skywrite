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
                    // Logs are for GitHub issues the developer can't reproduce, so the line says when to attach the file
                    // (user's wording, 2026-11-11).
                    Text("Logs")
                    Text("When you create an issue on GitHub, you can attach these logs to help us troubleshoot.").font(.callout)
                }
            } footer: {
                // The one thing that stays out, like 1Password's "Your secrets are not included in diagnostics
                // information" (support.1password.com/diagnostics-privacy, read 2026-11-11). Wording is the user's.
                // See LogReport for what else is hidden.
                Text("Your notes aren’t included in the logs.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
