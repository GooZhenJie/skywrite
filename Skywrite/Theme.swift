import SkywriteCore
import SwiftUI

enum Theme: String, CaseIterable, Identifiable {
    case skywriteDark
    case dusk
    case ocean
    case forest
    case skywriteLight
    case paper
    case mist
    /// A light green theme that goes with the dark Forest. It replaced Blossom, a pink theme, on 2026-11-07
    /// (user decision: pink was unlikely to be picked).
    case meadow

    var id: String { rawValue }

    static let dark: [Theme] = [.skywriteDark, .dusk, .ocean, .forest]
    static let light: [Theme] = [.skywriteLight, .paper, .mist, .meadow]

    /// Reads a stored theme. A Mac that had Blossom chosen gets Meadow, which replaced it.
    static func stored(_ value: String?) -> Theme? {
        ThemeMigration.currentName(forStored: value).flatMap(Theme.init(rawValue:))
    }

    var name: String {
        switch self {
        case .skywriteDark, .skywriteLight: "Skywrite"
        case .dusk: String(localized: "Dusk")
        case .ocean: String(localized: "Ocean")
        case .forest: String(localized: "Forest")
        case .paper: String(localized: "Paper")
        case .mist: String(localized: "Mist")
        case .meadow: String(localized: "Meadow")
        }
    }

    var isDark: Bool {
        Self.dark.contains(self)
    }

    var background: LinearGradient {
        let colors: [Color] = switch self {
        case .skywriteDark: [Color(red: 32 / 255, green: 36 / 255, blue: 42 / 255), Color(red: 32 / 255, green: 36 / 255, blue: 42 / 255)]
        case .dusk: [Color(red: 62 / 255, green: 38 / 255, blue: 50 / 255), Color(red: 32 / 255, green: 27 / 255, blue: 42 / 255)]
        case .ocean: [Color(red: 20 / 255, green: 46 / 255, blue: 62 / 255), Color(red: 18 / 255, green: 28 / 255, blue: 46 / 255)]
        case .forest: [Color(red: 26 / 255, green: 48 / 255, blue: 38 / 255), Color(red: 20 / 255, green: 31 / 255, blue: 29 / 255)]
        case .skywriteLight: [Color(red: 244 / 255, green: 244 / 255, blue: 247 / 255), Color(red: 244 / 255, green: 244 / 255, blue: 247 / 255)]
        // Paper and Meadow keep their own hue and lightness but are only as colorful as Mist: OKLCH chroma 0.011 to 0.012
        // at the top and 0.019 at the bottom, against Mist's 0.012 and 0.020 (whole RGB values can't match it exactly).
        // Their first colors looked too saturated next to Mist (user, 2026-11-07).
        case .paper: [Color(red: 251 / 255, green: 247 / 255, blue: 239 / 255), Color(red: 242 / 255, green: 234 / 255, blue: 221 / 255)]
        case .mist: [Color(red: 237 / 255, green: 244 / 255, blue: 251 / 255), Color(red: 222 / 255, green: 231 / 255, blue: 244 / 255)]
        // Forest's hues (153° and 169° in HSL), as light as Mist.
        case .meadow: [Color(red: 240 / 255, green: 250 / 255, blue: 246 / 255), Color(red: 225 / 255, green: 243 / 255, blue: 240 / 255)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var accent: Color {
        switch self {
        case .skywriteDark, .skywriteLight: Color(red: 0, green: 122 / 255, blue: 1)
        case .dusk: Color(red: 1, green: 138 / 255, blue: 92 / 255)
        case .ocean: Color(red: 61 / 255, green: 183 / 255, blue: 232 / 255)
        case .forest: Color(red: 76 / 255, green: 195 / 255, blue: 138 / 255)
        case .paper: Color(red: 194 / 255, green: 116 / 255, blue: 31 / 255)
        case .mist: Color(red: 47 / 255, green: 125 / 255, blue: 209 / 255)
        // Forest's accent hue and saturation, darkened until it stands out from the background as much as Mist's accent
        // does from Mist's (contrast about 3.4 : 1 against the darker end of the gradient).
        case .meadow: Color(red: 49 / 255, green: 146 / 255, blue: 99 / 255)
        }
    }
}
