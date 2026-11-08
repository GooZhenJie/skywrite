import SkywriteCore
import SwiftUI

struct StorageSettingsPane: View {
    @EnvironmentObject private var model: SettingsModel
    @EnvironmentObject private var preferences: Preferences

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    HStack {
                        Button("Change…") { model.chooseNotesFolder() }
                        Button("Show in Finder") { model.revealNotesFolder() }
                    }
                } label: {
                    Text((model.notesFolder.path as NSString).abbreviatingWithTildeInPath)
                    Text("\(model.noteCount) notes").font(.callout)
                }
            } header: {
                Text("Notes Folder")
            } footer: {
                Text("Closing a note doesn’t delete its file; deleting moves the file to the Trash.").font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section {
                Picker(selection: retention) {
                    ForEach(NoteRetention.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                } label: {
                    Text("Move to the Trash")
                    Text("Counted from the last edit, or from when you closed the note if that’s later.").font(.callout)
                }
                .accessibilityIdentifier("note-retention")
            } header: {
                Text("Closed Notes")
            } footer: {
                Text("Pinned notes and notes on your screen are never moved.").font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var retention: Binding<NoteRetention> {
        Binding(get: { preferences.noteRetention }, set: { choice in
            // Ask after the menu has closed; cancelling leaves the old choice showing.
            DispatchQueue.main.async {
                guard model.confirmRetention(choice) else { return }
                preferences.noteRetention = choice
            }
        })
    }
}

extension NoteRetention {
    var title: String {
        switch self {
        case .never: String(localized: "Never")
        case .oneDay: String(localized: "After one day")
        case .oneWeek: String(localized: "After one week")
        case .twoWeeks: String(localized: "After two weeks")
        case .oneMonth: String(localized: "After one month")
        case .oneYear: String(localized: "After one year")
        }
    }
}
