import Testing
@testable import SkywriteCore

struct GlassSettingTests {
    @Test func nothingStoredStartsAsSoftEdgeWithNoBackground() {
        let setting = GlassSetting(storedStyle: nil, storedStrength: nil)
        #expect(setting == GlassSetting(style: .softEdge, strength: 0))
        #expect(!setting.style.showsBackground(strength: setting.strength))
    }

    @Test func oldOffBecomesSoftEdgeAtZeroEvenWithAStoredStrength() {
        #expect(GlassSetting(storedStyle: "off", storedStrength: 0.8) == GlassSetting(style: .softEdge, strength: 0))
    }

    @Test func oldSoftEdgeKeepsTheStrengthItWasShownWith() {
        #expect(GlassSetting(storedStyle: "softEdge", storedStrength: nil) == GlassSetting(style: .softEdge, strength: 0.55))
        #expect(GlassSetting(storedStyle: "softEdge", storedStrength: 0.3) == GlassSetting(style: .softEdge, strength: 0.3))
    }

    @Test func oldCardBecomesLiquidGlass() {
        #expect(GlassSetting(storedStyle: "card", storedStrength: nil) == GlassSetting(style: .liquidGlass, strength: 0.55))
        #expect(GlassSetting(storedStyle: "card", storedStrength: 0.9) == GlassSetting(style: .liquidGlass, strength: 0.9))
    }

    @Test func liquidGlassReadsBack() {
        #expect(GlassSetting(storedStyle: "liquidGlass", storedStrength: 0.2) == GlassSetting(style: .liquidGlass, strength: 0.2))
        #expect(GlassSetting(storedStyle: "liquidGlass", storedStrength: nil) == GlassSetting(style: .liquidGlass, strength: 0))
    }

    @Test func unknownValueFallsBackToTheDefault() {
        #expect(GlassSetting(storedStyle: "frosted", storedStrength: 0.4) == GlassSetting(style: .softEdge, strength: 0))
    }

    @Test func strengthIsKeptBetweenZeroAndOne() {
        #expect(GlassSetting(storedStyle: "softEdge", storedStrength: 1.7).strength == 1)
        #expect(GlassSetting(storedStyle: "softEdge", storedStrength: -0.2).strength == 0)
    }

    @Test func onlyASoftEdgeAtZeroDrawsNothing() {
        #expect(!GlassStyle.softEdge.showsBackground(strength: 0))
        #expect(GlassStyle.softEdge.showsBackground(strength: 0.01))
        #expect(GlassStyle.liquidGlass.showsBackground(strength: 0))
    }
}
