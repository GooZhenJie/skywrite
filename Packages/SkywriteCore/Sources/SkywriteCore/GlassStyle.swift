import CoreGraphics

public enum GlassStyle: String, Codable, CaseIterable, Sendable {
    case softEdge
    case liquidGlass

    /// Space between the text and the edge of the note. Liquid Glass hugs the box, so its padding grows with zoom like its corners do.
    public func textPadding(zoom: CGFloat) -> CGSize {
        switch self {
        case .softEdge: CGSize(width: NoteMetrics.textHorizontalPadding, height: NoteMetrics.textVerticalPadding)
        case .liquidGlass: CGSize(width: NoteMetrics.liquidGlassPadding * zoom, height: NoteMetrics.liquidGlassPadding * zoom)
        }
    }

    /// A soft edge at zero strength draws nothing, so clicks around the text pass through to the app behind.
    public func showsBackground(strength: Double) -> Bool {
        switch self {
        case .softEdge: strength > 0
        case .liquidGlass: true
        }
    }
}

public struct GlassSetting: Equatable, Sendable {
    public var style: GlassStyle
    public var strength: Double

    public init(style: GlassStyle, strength: Double) {
        self.style = style
        self.strength = min(1, max(0, strength))
    }

    /// Reads what any version stored. Older versions also had "off", which looked exactly like a soft edge at zero strength,
    /// and "card", which became Liquid Glass. Their strength slider started at 0.55 and was only stored once moved.
    public init(storedStyle: String?, storedStrength: Double?) {
        switch storedStyle {
        case GlassStyle.softEdge.rawValue:
            self.init(style: .softEdge, strength: storedStrength ?? NoteMetrics.legacyDefaultGlassStrength)
        case "card":
            self.init(style: .liquidGlass, strength: storedStrength ?? NoteMetrics.legacyDefaultGlassStrength)
        case GlassStyle.liquidGlass.rawValue:
            self.init(style: .liquidGlass, strength: storedStrength ?? NoteMetrics.defaultGlassStrength)
        default:
            self.init(style: .softEdge, strength: NoteMetrics.defaultGlassStrength)
        }
    }
}
