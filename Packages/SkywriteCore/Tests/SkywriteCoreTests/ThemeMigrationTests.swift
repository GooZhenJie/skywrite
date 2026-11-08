import Testing
@testable import SkywriteCore

struct ThemeMigrationTests {
    @Test func blossomBecomesMeadow() {
        #expect(ThemeMigration.currentName(forStored: "blossom") == "meadow")
    }

    @Test func otherNamesAreReadAsTheyAre() {
        for name in ["meadow", "paper", "mist", "skywriteLight", "forest", "something-new"] {
            #expect(ThemeMigration.currentName(forStored: name) == name)
        }
    }

    @Test func nothingStoredStaysNothing() {
        #expect(ThemeMigration.currentName(forStored: nil) == nil)
    }
}
