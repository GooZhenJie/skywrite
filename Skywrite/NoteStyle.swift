import AppKit
import SkywriteCore

struct NoteStyle: Equatable {
    var fontSize: CGFloat
    var glassStyle: GlassStyle
    var glassStrength: Double
    var liquidGlassStaysClear: Bool

    func font(zoom: CGFloat) -> NSFont {
        NSFont.systemFont(ofSize: fontSize * zoom, weight: .medium)
    }

    func lineHeight(zoom: CGFloat) -> CGFloat {
        NSLayoutManager().defaultLineHeight(for: font(zoom: zoom))
    }

    func textPadding(zoom: CGFloat) -> CGSize {
        glassStyle.textPadding(zoom: zoom)
    }

    var showsBackground: Bool {
        glassStyle.showsBackground(strength: glassStrength)
    }

}

struct RecentNote {
    let id: UUID
    let title: String
    let isOnScreen: Bool
    let modifiedAt: Date
}
