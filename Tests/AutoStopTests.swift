import Testing
import Foundation
@testable import TimeTracker

@Suite("AutoStopSchedule")
struct AutoStopScheduleTests {

    let calendar = Calendar.current
    let schedule = AutoStopSchedule(minutesAfterMidnight: 17 * 60)

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 4, day: day, hour: hour, minute: minute))!
    }

    @Test("Cutoff falls on the same calendar day at the configured time")
    func cutoffOnDay() {
        #expect(schedule.cutoff(onDayOf: date(10, 9)) == date(10, 17))
    }

    @Test("Detects a crossed cutoff")
    func crossed() {
        #expect(schedule.firstCutoff(after: date(10, 16, 59), through: date(10, 17, 1)) == date(10, 17))
    }

    @Test("End exactly at cutoff counts as crossed")
    func inclusiveEnd() {
        #expect(schedule.firstCutoff(after: date(10, 16), through: date(10, 17)) == date(10, 17))
    }

    @Test("No cutoff when window is entirely before it")
    func beforeCutoff() {
        #expect(schedule.firstCutoff(after: date(10, 9), through: date(10, 16)) == nil)
    }

    @Test("No cutoff when window starts after today's cutoff and ends before tomorrow's")
    func afterCutoff() {
        #expect(schedule.firstCutoff(after: date(10, 18), through: date(11, 9)) == nil)
    }

    @Test("Window starting after today's cutoff finds tomorrow's")
    func nextDay() {
        #expect(schedule.firstCutoff(after: date(10, 18), through: date(11, 18)) == date(11, 17))
    }

    @Test("Multi-day window returns the first cutoff")
    func multiDay() {
        #expect(schedule.firstCutoff(after: date(10, 9), through: date(13, 9)) == date(10, 17))
    }

    @Test("Clamps out-of-range minutes")
    func clamp() {
        #expect(AutoStopSchedule.clamp(-5) == 0)
        #expect(AutoStopSchedule.clamp(5000) == 1439)
    }
}

@Suite("TimerSession.stopTimers")
struct TimerSessionStopTests {

    @Test("Stops timers and credits time only up to the cutoff")
    func stopsAtCutoff() {
        let cutoff = Date()
        var session = TimerSession(
            accumulated: ["a": 100],
            activeLabelId: "a",
            activeStartedAt: cutoff.addingTimeInterval(-60),
            day: "2026-04-10",
            independentAccumulated: ["i": 10],
            activeIndependentTimers: ["i": cutoff.addingTimeInterval(-30)]
        )
        session.stopTimers(at: cutoff)
        #expect(session.activeLabelId == nil)
        #expect(session.activeStartedAt == nil)
        #expect(session.activeIndependentTimers.isEmpty)
        #expect(abs(session.accumulated["a", default: 0] - 160) < 0.001)
        #expect(abs(session.independentAccumulated["i", default: 0] - 40) < 0.001)
    }

    @Test("Timers started after the cutoff keep running")
    func leavesLaterTimers() {
        let cutoff = Date()
        let later = cutoff.addingTimeInterval(5)
        var session = TimerSession(
            accumulated: ["a": 0],
            activeLabelId: "a",
            activeStartedAt: later,
            day: "2026-04-10",
            activeIndependentTimers: ["i": later]
        )
        session.stopTimers(at: cutoff)
        #expect(session.activeLabelId == "a")
        #expect(session.activeIndependentTimers["i"] == later)
        #expect(session.accumulated["a"] == 0)
    }
}

@Suite("TimerViewModel auto-stop", .serialized)
@MainActor
struct TimerViewModelAutoStopTests {

    let viewModel: TimerViewModel

    init() {
        UserDefaults.standard.removeObject(forKey: AppConstants.autoStopEnabledKey)
        UserDefaults.standard.removeObject(forKey: AppConstants.autoStopMinutesKey)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeTrackerTests-\(UUID().uuidString)")
        viewModel = TimerViewModel(persistence: PersistenceService(baseURL: tempDir))
    }

    @Test("Defaults to disabled at 5:00 PM")
    func defaults() {
        #expect(viewModel.autoStopEnabled == false)
        #expect(viewModel.autoStopMinutes == AppConstants.defaultAutoStopMinutes)
    }

    @Test("Stops running timers when the cutoff is crossed")
    func stopsWhenEnabled() {
        let now = Date()
        // Place the cutoff 1 minute from now, then check 2 minutes from now.
        let comps = Calendar.current.dateComponents([.hour, .minute], from: now.addingTimeInterval(60))
        viewModel.autoStopMinutes = comps.hour! * 60 + comps.minute!
        viewModel.autoStopEnabled = true
        viewModel.tap(TimerLabel.defaults[0])
        viewModel.tapIndependentTimer(IndependentTimerLabel.defaults[0])

        viewModel.checkAutoStop(now: now.addingTimeInterval(120))

        #expect(viewModel.session.activeLabelId == nil)
        #expect(viewModel.session.activeIndependentTimers.isEmpty)
        viewModel.autoStopEnabled = false
    }

    @Test("Does nothing when disabled")
    func noopWhenDisabled() {
        let now = Date()
        let comps = Calendar.current.dateComponents([.hour, .minute], from: now.addingTimeInterval(60))
        viewModel.autoStopMinutes = comps.hour! * 60 + comps.minute!
        viewModel.autoStopEnabled = false
        let label = TimerLabel.defaults[0]
        viewModel.tap(label)

        viewModel.checkAutoStop(now: now.addingTimeInterval(120))

        #expect(viewModel.session.activeLabelId == label.id)
    }

    @Test("Setting auto-stop time via Date updates minutes")
    func timeBinding() {
        let date = Calendar.current.date(bySettingHour: 18, minute: 30, second: 0, of: Date())!
        viewModel.autoStopTime = date
        #expect(viewModel.autoStopMinutes == 18 * 60 + 30)
    }
}
