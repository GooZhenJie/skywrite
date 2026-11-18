import AppKit
import SkywriteCore
import SwiftUI

/// The quick panel as drawn in the mock-up approved on 2026-11-17: search field and filters
/// on top, the list on the left, the picked note on the right, what Return does along the bottom.
struct QuickPanelView: View {
    @ObservedObject var model: QuickPanelModel
    @EnvironmentObject private var preferences: Preferences
    @Environment(\.colorScheme) private var colorScheme

    private var accent: Color {
        (colorScheme == .dark ? preferences.darkTheme : preferences.lightTheme).accent
    }

    /// The faint fill behind the search field, the filters and the preview, so they stand apart from the glass.
    private var fill: Color {
        colorScheme == .dark ? .white.opacity(0.08) : .white.opacity(0.6)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if model.matches.isEmpty {
                emptyState
            } else {
                HStack(spacing: 0) {
                    list
                        .frame(width: 300)
                    Divider()
                    if let match = model.selectedMatch {
                        QuickPanelPreview(match: match, terms: model.terms, now: model.now, accent: accent, fill: fill)
                    }
                }
            }
            Divider()
            actionBar
        }
        .frame(width: NoteMetrics.quickPanelWidth, height: NoteMetrics.quickPanelHeight)
        .tint(accent)
    }

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                QuickPanelSearchField(model: model)
            }
            .padding(.horizontal, 16)
            .frame(height: 42)
            .background(Capsule().fill(fill))
            HStack(spacing: 6) {
                ForEach(NoteFilter.allCases, id: \.self) { filter in
                    filterButton(filter)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private func filterButton(_ filter: NoteFilter) -> some View {
        let isOn = model.filter == filter
        return Button {
            model.filter = filter
            model.focusSearchField()
        } label: {
            HStack(spacing: 6) {
                if let symbol = filter.symbol {
                    Image(systemName: symbol)
                }
                Text(filter.title)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Capsule().fill(isOn ? accent : fill))
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Not LazyVStack: with it, rows already drawn kept their old selection and bold words while you typed
                // (reproduced 2026-11-17 with an in-app check).
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(model.sections, id: \.kind) { section in
                        if let title = section.kind.title {
                            Text(title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.top, 8)
                                .padding(.bottom, 3)
                        }
                        ForEach(section.matches) { match in
                            QuickPanelRow(match: match, isSelected: match.id == model.selection, now: model.now, accent: accent)
                                .gesture(TapGesture().onEnded {
                                    model.selection = match.id
                                    model.focusSearchField()
                                })
                                .simultaneousGesture(TapGesture(count: 2).onEnded {
                                    model.open(match.id)
                                })
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .onChange(of: model.selection) { _, selection in
                guard let selection else { return }
                proxy.scrollTo(selection)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text(model.notes.isEmpty ? String(localized: "No notes yet") : String(localized: "No Results"))
                .font(.system(size: 17, weight: .semibold))
            // Only after a search that found nothing, or with no notes at all: a filter with nothing in it isn't a reason
            // to write a new note.
            if let shortcut = model.newNoteShortcut, model.notes.isEmpty || !model.terms.isEmpty {
                Text("Press \(shortcut.symbols.joined()) to write a new note.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var actionBar: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 18, height: 18)
                Text(verbatim: "Skywrite")
            }
            Spacer()
            if let match = model.selectedMatch {
                action(match.note.isOnScreen ? String(localized: "Bring to Front") : String(localized: "Show on Screen"), key: "↩") {
                    model.open(match.id)
                }
            }
            action(String(localized: "Close"), key: "esc") {
                model.close()
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .frame(height: 42)
    }

    private func action(_ title: String, key: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 6) {
                Text(title)
                Text(verbatim: key)
                    .font(.system(size: 12))
                    .padding(.horizontal, 5)
                    .frame(minWidth: 22, minHeight: 20)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.07)))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// One note in the list: its first line, then where the search matched lower down and when it was last edited, with a pin
/// and an eye on the right when it's pinned or on screen.
private struct QuickPanelRow: View {
    let match: NoteMatch
    let isSelected: Bool
    let now: Date
    let accent: Color

    private var secondary: Color {
        isSelected ? .white.opacity(0.85) : .secondary
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(QuickPanelText.marked(match.title, match.titleMatches, accent: isSelected ? nil : accent))
                    .font(.system(size: 14))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                if match.note.isPinned {
                    Image(systemName: "pin")
                }
                if match.note.isOnScreen {
                    Image(systemName: "eye")
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(secondary)
            .padding(.top, 3)
        }
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? accent : Color.clear))
        .contentShape(Rectangle())
    }

    private var subtitle: AttributedString {
        let time = AttributedString(RelativeTime.text(for: match.note.modifiedAt, now: now))
        guard let excerpt = match.excerpt else { return time }
        return QuickPanelText.marked(excerpt, match.excerptMatches, accent: isSelected ? nil : accent) + AttributedString(" · ") + time
    }
}

/// The picked note the way it shows on screen, read only, with when it was edited and made and whether it's on screen below.
private struct QuickPanelPreview: View {
    let match: NoteMatch
    let terms: [String]
    let now: Date
    let accent: Color
    let fill: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                QuickPanelNoteText(display: match.note.display, terms: terms, highlight: accent.opacity(0.22))
                    .font(.system(size: QuickPanelNoteText.fontSize))
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .id(match.id)
            .background(RoundedRectangle(cornerRadius: 14).fill(fill))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 3) {
                GridRow {
                    Text("Edited").foregroundStyle(.secondary)
                    Text(RelativeTime.text(for: match.note.modifiedAt, now: now))
                }
                GridRow {
                    Text("Created").foregroundStyle(.secondary)
                    Text(match.note.createdAt.formatted(date: .abbreviated, time: .shortened))
                }
                GridRow {
                    Text("Status").foregroundStyle(.secondary)
                    Text(match.note.isOnScreen ? String(localized: "On Screen") : String(localized: "Closed"))
                }
            }
            .font(.system(size: 12))
            .padding(.top, 10)
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

enum QuickPanelText {
    /// The words you searched for in bold, and in `accent` when one is given (not on the picked row, which is accent already).
    static func marked(_ text: String, _ ranges: [Range<String.Index>], accent: Color?) -> AttributedString {
        var attributed = AttributedString(text)
        for range in ranges {
            guard let found = Range(range, in: attributed) else { continue }
            attributed[found].inlinePresentationIntent = .stronglyEmphasized
            if let accent {
                attributed[found].foregroundColor = accent
            }
        }
        return attributed
    }

    /// The text with every word you searched for on a tinted background.
    static func highlighted(_ text: String, terms: [String], color: Color) -> AttributedString {
        var attributed = AttributedString(text)
        for range in NoteSearch.ranges(of: terms, in: text) {
            guard let found = Range(range, in: attributed) else { continue }
            attributed[found].backgroundColor = color
        }
        return attributed
    }
}

private extension NoteFilter {
    var title: String {
        switch self {
        case .all: String(localized: "All")
        case .onScreen: String(localized: "On Screen")
        case .pinned: String(localized: "Pinned")
        }
    }

    /// The same symbols the rows use for the same thing.
    var symbol: String? {
        switch self {
        case .all: nil
        case .onScreen: "eye"
        case .pinned: "pin"
        }
    }
}

private extension NoteSection.Kind {
    var title: String? {
        switch self {
        case .pinned: String(localized: "Pinned")
        case .today: String(localized: "Today")
        case .earlier: String(localized: "Earlier")
        case .results: nil
        }
    }
}
