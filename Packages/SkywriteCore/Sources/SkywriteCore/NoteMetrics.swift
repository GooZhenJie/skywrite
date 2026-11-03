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

    public static var windowMargin: CGFloat {
        frameGap + handleHitThickness / 2
    }
}
