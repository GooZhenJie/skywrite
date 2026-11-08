import SkywriteCore
import Testing

@Suite struct SettingsSearchTests {
    @Test func emptyOrBlankQueryShowsEverything() {
        #expect(SettingsSearch.matches("", names: ["General"]))
        #expect(SettingsSearch.matches("   ", names: ["General"]))
    }

    @Test func matchesPartOfAnyNameIgnoringCase() {
        #expect(SettingsSearch.matches("dock", names: ["General", "Dock"]))
        #expect(SettingsSearch.matches("GLASS", names: ["Liquid Glass"]))
        #expect(SettingsSearch.matches(" trash ", names: ["Move to the Trash"]))
    }

    @Test func matchesChineseNames() {
        #expect(SettingsSearch.matches("玻璃", names: ["液态玻璃"]))
    }

    @Test func noMatchWhenNoNameContainsTheQuery() {
        #expect(!SettingsSearch.matches("wallpaper", names: ["General", "Dock", "Menu bar"]))
    }
}
