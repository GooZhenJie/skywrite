import Testing
@testable import SkywriteCore

struct DoubleTapDetectorTests {
    let rightOption = ModifierKey.rightOption.keyCode
    let leftOption = ModifierKey.leftOption.keyCode

    func tap(_ detector: inout DoubleTapDetector, keyCode: UInt16, down: Double, up: Double, othersDown: Bool = false) -> Bool {
        _ = detector.modifierChanged(keyCode: keyCode, isDown: true, otherModifiersDown: othersDown, at: down)
        return detector.modifierChanged(keyCode: keyCode, isDown: false, otherModifiersDown: othersDown, at: up)
    }

    @Test func twoQuickTapsTrigger() {
        var detector = DoubleTapDetector(key: .rightOption, interval: 0.5)
        #expect(tap(&detector, keyCode: rightOption, down: 0, up: 0.05) == false)
        #expect(tap(&detector, keyCode: rightOption, down: 0.15, up: 0.2) == true)
    }

    @Test func slowTapsDoNotTrigger() {
        var detector = DoubleTapDetector(key: .rightOption, interval: 0.5)
        #expect(tap(&detector, keyCode: rightOption, down: 0, up: 0.05) == false)
        #expect(tap(&detector, keyCode: rightOption, down: 0.6, up: 0.7) == false)
    }

    @Test func thirdTapStartsOver() {
        var detector = DoubleTapDetector(key: .rightOption, interval: 0.5)
        _ = tap(&detector, keyCode: rightOption, down: 0, up: 0.05)
        #expect(tap(&detector, keyCode: rightOption, down: 0.1, up: 0.15) == true)
        #expect(tap(&detector, keyCode: rightOption, down: 0.2, up: 0.25) == false)
    }

    @Test func otherKeyBetweenTapsCancels() {
        var detector = DoubleTapDetector(key: .rightOption, interval: 0.5)
        _ = tap(&detector, keyCode: rightOption, down: 0, up: 0.05)
        detector.interrupt()
        #expect(tap(&detector, keyCode: rightOption, down: 0.1, up: 0.15) == false)
    }

    @Test func keyPressedWhileHoldingCancels() {
        var detector = DoubleTapDetector(key: .rightOption, interval: 0.5)
        _ = tap(&detector, keyCode: rightOption, down: 0, up: 0.05)
        _ = detector.modifierChanged(keyCode: rightOption, isDown: true, otherModifiersDown: false, at: 0.1)
        detector.interrupt()
        #expect(detector.modifierChanged(keyCode: rightOption, isDown: false, otherModifiersDown: false, at: 0.15) == false)
    }

    @Test func otherModifierHeldCancels() {
        var detector = DoubleTapDetector(key: .rightOption, interval: 0.5)
        _ = tap(&detector, keyCode: rightOption, down: 0, up: 0.05)
        #expect(tap(&detector, keyCode: rightOption, down: 0.1, up: 0.15, othersDown: true) == false)
    }

    @Test func leftOptionIgnoredForRightOption() {
        var detector = DoubleTapDetector(key: .rightOption, interval: 0.5)
        #expect(tap(&detector, keyCode: leftOption, down: 0, up: 0.05) == false)
        #expect(tap(&detector, keyCode: leftOption, down: 0.1, up: 0.15) == false)
    }

    @Test func eitherOptionAcceptsLeft() {
        var detector = DoubleTapDetector(key: .eitherOption, interval: 0.5)
        _ = tap(&detector, keyCode: leftOption, down: 0, up: 0.05)
        #expect(tap(&detector, keyCode: leftOption, down: 0.1, up: 0.15) == true)
    }

    @Test func rightCommandOnlyMatchesRightCommand() {
        #expect(TapKey.rightCommand.matches(keyCode: ModifierKey.rightCommand.keyCode))
        #expect(!TapKey.rightCommand.matches(keyCode: ModifierKey.leftCommand.keyCode))
    }

    @Test func modifierStateReadsDeviceFlags() {
        let flags = ModifierKey.rightOption.deviceMask | ModifierKey.leftShift.deviceMask
        #expect(ModifierKey.isDown(keyCode: rightOption, deviceFlags: flags) == true)
        #expect(ModifierKey.isDown(keyCode: leftOption, deviceFlags: flags) == false)
        #expect(ModifierKey.isDown(keyCode: 0x00, deviceFlags: flags) == nil)
        #expect(ModifierKey.othersAreDown(besides: rightOption, deviceFlags: flags) == true)
        #expect(ModifierKey.othersAreDown(besides: rightOption, deviceFlags: ModifierKey.rightOption.deviceMask) == false)
    }
}
