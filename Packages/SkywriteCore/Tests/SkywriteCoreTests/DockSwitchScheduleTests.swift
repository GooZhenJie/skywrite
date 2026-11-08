import Testing
@testable import SkywriteCore

struct DockSwitchScheduleTests {
    @Test func firstSwitchHappensRightAway() {
        var schedule = DockSwitchSchedule(applied: false, minimumInterval: 1)
        #expect(schedule.request(true, now: 10) == 0)
        #expect(schedule.fire(now: 10) == true)
    }

    @Test func secondSwitchWaitsForTheInterval() {
        var schedule = DockSwitchSchedule(applied: false, minimumInterval: 1)
        _ = schedule.request(true, now: 10)
        _ = schedule.fire(now: 10)
        let delay = schedule.request(false, now: 10.3) ?? 0
        #expect(abs(delay - 0.7) < 0.000_001)
        #expect(schedule.fire(now: 10.5) == nil)
        #expect(schedule.fire(now: 11) == false)
    }

    @Test func undoneRequestChangesNothing() {
        var schedule = DockSwitchSchedule(applied: false, minimumInterval: 1)
        _ = schedule.request(true, now: 10)
        _ = schedule.fire(now: 10)
        _ = schedule.request(false, now: 10.2)
        #expect(schedule.request(true, now: 10.4) == nil)
        #expect(schedule.fire(now: 11) == nil)
        #expect(schedule.applied == true)
    }

    @Test func burstEndsOnTheLastRequestWithFewSwitches() {
        var schedule = DockSwitchSchedule(applied: false, minimumInterval: 1)
        var switches = 0
        var visible = false
        var pendingFireAt: Double?
        for step in 0..<20 {
            let now = Double(step) * 0.15
            if let fireAt = pendingFireAt, fireAt <= now {
                if schedule.fire(now: fireAt) != nil { switches += 1 }
                pendingFireAt = nil
            }
            visible.toggle()
            if let delay = schedule.request(visible, now: now), pendingFireAt == nil {
                pendingFireAt = now + delay
            }
        }
        while let fireAt = pendingFireAt {
            pendingFireAt = nil
            if schedule.fire(now: fireAt) != nil { switches += 1 }
            if let delay = schedule.delay(now: fireAt) { pendingFireAt = fireAt + delay }
        }
        #expect(schedule.applied == visible)
        #expect(switches <= 4)
    }
}
