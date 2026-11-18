import CoreGraphics

public enum NoteMetrics {
    public static let baseFontSize: CGFloat = 20
    public static let textHorizontalPadding: CGFloat = 4
    public static let textVerticalPadding: CGFloat = 2
    public static let minimumTextWidth: CGFloat = 24
    public static let minimumFixedWidth: CGFloat = 60
    public static let screenEdgeMargin: CGFloat = 12
    public static let frameGap: CGFloat = 6
    public static let cornerArmLength: CGFloat = 12
    public static let cornerToEdgeGap: CGFloat = 6
    public static let handleHitThickness: CGFloat = 14
    public static let edgeLineWidth: CGFloat = 1.5
    /// The lighter rounded tile behind each cell of a note with cells. The text stays where a plain note puts it, so the
    /// note is no bigger than its text needs, and each tile's edge sits halfway between the note's edge and the text: the
    /// text is as far inside its tile as the tile is inside the note. See `NoteCellGeometry.spacing(layout:textPadding:)`.
    public static let cellTileInsetShare: CGFloat = 0.5
    public static let cellTileOpacity: CGFloat = 0.06
    /// Lists, in multiples of the note's font size, as Notion draws them: measured on a public notion.site page
    /// (beattech.notion.site "Bullet list item", 2026-11-16) with 16px text, the bullet or number sits centred in a 24px
    /// column, the text starts 30px in, wrapped lines too, and the bullet is drawn at 24px.
    public static let listMarkerColumnScale: CGFloat = 1.5
    public static let listTextIndentScale: CGFloat = 1.875
    public static let listBulletScale: CGFloat = 1.5
    /// A task's box, as Notion draws a to-do: measured on a public notion.site page (beattech.notion.site "Todo",
    /// 2026-11-16) with 16px text, the box is 16px square with a 1px border and 1.5px corners, centred in the same 24px
    /// column as a bullet and on the middle of the line's text, which starts 30px in like any list item's. A ticked
    /// item's text is drawn at 70% opacity with a line through it in the text's colour at half opacity.
    public static let taskBoxScale: CGFloat = 1
    public static let taskBoxBorderScale: CGFloat = 1.0 / 16
    public static let taskBoxCornerScale: CGFloat = 1.5 / 16
    public static let checkedTaskTextOpacity: CGFloat = 0.7
    public static let checkedTaskLineOpacity: CGFloat = 0.5
    public static let cornerLineWidth: CGFloat = 2
    public static let edgeDashPattern: [CGFloat] = [3, 3]
    public static let handleRestingOpacity: CGFloat = 0.3
    public static let handleHighlightedOpacity: CGFloat = 0.7
    public static let dragThreshold: CGFloat = 4
    public static let minimumZoom: Double = 0.3
    public static let maximumZoom: Double = 5
    public static let preciseScrollZoomSensitivity: Double = 0.0015
    public static let lineScrollZoomSensitivity: Double = 0.15
    public static let recordSaveDelay: Double = 0.5
    public static let minimumFontSize: CGFloat = 10
    public static let maximumFontSize: CGFloat = 72
    public static let fontSizeStep: CGFloat = 1
    public static let menuTitleMaximumLength = 40
    public static let recentNotesInMenu = 6
    /// The shortest retention is one day, so checking every hour moves a note at most an hour late.
    public static let retentionCheckInterval: Double = 60 * 60
    public static let defaultGlassStrength: Double = 0
    public static let legacyDefaultGlassStrength: Double = 0.55
    public static let softEdgeFeather: CGFloat = 14
    public static let liquidGlassCornerRadius: CGFloat = 12
    /// Apple's concentric rule makes an inner corner the outer radius minus the padding; text has square corners, so the padding equals the radius.
    public static let liquidGlassPadding: CGFloat = liquidGlassCornerRadius
    public static let placementHintHorizontalPadding: CGFloat = 8
    public static let placementHintVerticalPadding: CGFloat = 3
    public static let placementHintCornerRadius: CGFloat = 6

    /// The quick panel's size and corner, from the mock-up approved on 2026-11-17. Placeholders,
    /// not measured against anything; to be settled on screen.
    public static let quickPanelWidth: CGFloat = 760
    public static let quickPanelHeight: CGFloat = 460
    public static let quickPanelCornerRadius: CGFloat = 26
    /// How far below the top of the screen the panel sits, as a share of the screen's height. Also a placeholder.
    public static let quickPanelTopShare: CGFloat = 0.18

    /// The glass's corner radius minus how far in the tile sits, the concentric rule used for `liquidGlassPadding`: 12 - 6.
    public static var cellTileCornerRadius: CGFloat {
        liquidGlassCornerRadius - liquidGlassPadding * cellTileInsetShare
    }

    public static var windowMargin: CGFloat {
        frameGap + handleHitThickness / 2
    }
}
