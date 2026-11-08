/// Theme names that older versions stored, and the theme that replaced each.
public enum ThemeMigration {
    /// The light themes' pink Blossom became the green Meadow on 2026-11-07 (user decision: pink was unlikely to be picked),
    /// so a Mac that had Blossom chosen gets Meadow. Every other name is read as it is.
    public static func currentName(forStored name: String?) -> String? {
        name == "blossom" ? "meadow" : name
    }
}
