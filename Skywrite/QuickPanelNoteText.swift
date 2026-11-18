import AppKit
import SkywriteCore
import SwiftUI

/// The note the way it shows on screen (see `NoteDisplay`), drawn with the note's own rules scaled to the preview's text
/// size: headings larger and semibold, a bullet, number or box in a column in front of each list item, a ticked task
/// faded with a line through it, and a note with cells as lighter tiles spaced the way the note spaces them: the preview
/// shows what the note shows, not its Markdown. Every word searched for is tinted.
struct QuickPanelNoteText: View {
    let display: NoteDisplay
    let terms: [String]
    let highlight: Color

    /// The preview's text size, kept from the plain-text preview it replaces.
    static let fontSize: CGFloat = 15
    /// The space around the text of a plain note in the preview, kept from the plain-text preview it replaces. A note
    /// with cells splits it into the space around the tiles and inside them, as `NoteCellGeometry.spacing` does in a note.
    private static let padding = CGSize(width: 18, height: 16)

    var body: some View {
        if display.layout.isGrid {
            let spacing = NoteCellGeometry.spacing(layout: display.layout, textPadding: Self.padding)
            Grid(alignment: .topLeading, horizontalSpacing: spacing.gap.width, verticalSpacing: spacing.gap.height) {
                ForEach(Array(display.layout.rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(row, id: \.self) { index in
                            blocks(display.cells[index])
                                .padding(.horizontal, spacing.padding.width)
                                .padding(.vertical, spacing.padding.height)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .background(RoundedRectangle(cornerRadius: NoteMetrics.cellTileCornerRadius).fill(Color.primary.opacity(NoteMetrics.cellTileOpacity)))
                        }
                    }
                }
            }
            .padding(.horizontal, spacing.margin.width)
            .padding(.vertical, spacing.margin.height)
        } else {
            blocks(display.cells.first ?? [])
                .padding(.horizontal, Self.padding.width)
                .padding(.vertical, Self.padding.height)
        }
    }

    private func blocks(_ blocks: [NoteDisplayBlock]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                self.block(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func block(_ block: NoteDisplayBlock) -> some View {
        switch block.kind {
        case .text:
            Text(marked(block.text))
        case .heading(let level):
            let scales = NoteMarkdown.headingScales
            Text(marked(block.text))
                .font(.system(size: Self.fontSize * scales[min(max(level, 1), scales.count) - 1], weight: .semibold))
        case .bullet:
            item(bullet, text: block.text)
        case .numbered(let label):
            item(Text(label), text: block.text)
        case .task(let isChecked):
            item(Text(Image(systemName: isChecked ? "checkmark.square.fill" : "square"))
                .foregroundStyle(isChecked ? Color(nsColor: NoteListMarker.checkedFill) : Color.primary), text: block.text, isChecked: isChecked)
        }
    }

    /// The note's bullet: a dot as big as "•" in the note's larger bullet size (`NoteMetrics.listBulletScale`), centred on
    /// the middle of the lowercase letters beside it, the way `NoteListMarker` draws it. A dot rather than a larger "•"
    /// character, which would make the item's first line taller than the text's.
    private var bullet: some View {
        let halfXHeight = NSFont.systemFont(ofSize: Self.fontSize).xHeight / 2
        let glyph = ("•" as NSString).boundingRect(with: .zero, options: [.usesDeviceMetrics], attributes: [.font: NSFont.systemFont(ofSize: Self.fontSize * NoteMetrics.listBulletScale)])
        return Circle()
            .frame(width: glyph.width, height: glyph.width)
            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + halfXHeight }
    }

    /// A list item: its marker centred in a column as wide as the note's, then its text, so wrapped lines and the lines
    /// continuing the item line up with its first line.
    private func item(_ marker: some View, text: String, isChecked: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            marker
                .frame(width: Self.fontSize * NoteMetrics.listMarkerColumnScale)
            Text(marked(text, isChecked: isChecked))
        }
    }

    /// An empty line still takes a line's height, as it does in the note.
    private func marked(_ text: String, isChecked: Bool = false) -> AttributedString {
        var attributed = QuickPanelText.highlighted(text.isEmpty ? " " : text, terms: terms, color: highlight)
        if isChecked {
            attributed.foregroundColor = Color.primary.opacity(NoteMetrics.checkedTaskTextOpacity)
            attributed.strikethroughStyle = .single
        }
        return attributed
    }
}
