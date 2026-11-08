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

    public static var windowMargin: CGFloat {
        frameGap + handleHitThickness / 2
    }
}
