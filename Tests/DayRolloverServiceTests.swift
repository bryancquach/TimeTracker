import Testing
import Foundation
@testable import TimeTracker

@Suite("DayRolloverService")
struct DayRolloverServiceTests {

    let service = DayRolloverService()
    let labels = TimerLabel.defaults
    let independentLabels = IndependentTimerLabel.defaults

    @Test("Same day returns nil (no rollover needed)")
    func sameDayNoOp() {
        let session = TimerSession.fresh(day: "2026-04-29", labels: labels, independentLabels: independentLabels)
        let result = service.rolloverIfNeeded(
            session: session, today: "2026-04-29",
            labels: labels, independentLabels: independentLabels
        )
        #expect(result == nil)
    }

    @Test("Rollover creates fresh session for new day")
    func rolloverCreatesFreshSession() {
        let session = TimerSession.fresh(day: "2026-04-28", labels: labels, independentLabels: independentLabels)
        let result = service.rolloverIfNeeded(
            session: session, today: "2026-04-29",
            labels: labels, independentLabels: independentLabels
        )
        #expect(result != nil)
        #expect(result!.newSession.day == "2026-04-29")
        #expect(result!.newSession.activeLabelId == nil)
    }

    @Test("Stale session is returned for logging when within limit")
    func staleSessionReturnedWithinLimit() {
        var session = TimerSession.fresh(day: "2026-04-28", labels: labels, independentLabels: independentLabels)
        session.accumulated["project_1"] = 3600
        let result = service.rolloverIfNeeded(
            session: session, today: "2026-04-29",
            labels: labels, independentLabels: independentLabels
        )
        #expect(result!.staleSessionToLog != nil)
        #expect(result!.staleSessionToLog!.day == "2026-04-28")
        #expect(result!.staleSessionToLog!.accumulated["project_1"] == 3600)
    }

    @Test("Stale session has active timer metadata cleared")
    func staleSessionClearsActiveMetadata() {
        var session = TimerSession.fresh(day: "2026-04-28", labels: labels, independentLabels: independentLabels)
        session.activeLabelId = "project_1"
        session.activeStartedAt = Date()
        session.activeIndependentTimers["independent_timer"] = Date()
        let result = service.rolloverIfNeeded(
            session: session, today: "2026-04-29",
            labels: labels, independentLabels: independentLabels
        )
        #expect(result!.staleSessionToLog!.activeLabelId == nil)
        #expect(result!.staleSessionToLog!.activeStartedAt == nil)
        #expect(result!.staleSessionToLog!.activeIndependentTimers.isEmpty)
    }

    @Test("Rollover restarts active regular timer from midnight on new session")
    func rolloverRestartsRegularTimerFromMidnight() {
        var session = TimerSession.fresh(day: "2026-04-28", labels: labels, independentLabels: independentLabels)
        session.activeLabelId = "project_1"
        session.activeStartedAt = Date()
        let result = service.rolloverIfNeeded(
            session: session, today: "2026-04-29",
            labels: labels, independentLabels: independentLabels
        )
        #expect(result!.newSession.activeLabelId == "project_1")
        #expect(result!.newSession.activeStartedAt != nil)
        let midnight = TimerSession.startOfDay(for: "2026-04-29")!
        #expect(result!.newSession.activeStartedAt == midnight)
    }

    @Test("Rollover restarts active independent timers from midnight")
    func rolloverRestartsIndependentTimersFromMidnight() {
        var session = TimerSession.fresh(day: "2026-04-28", labels: labels, independentLabels: independentLabels)
        session.activeIndependentTimers["independent_timer"] = Date()
        let result = service.rolloverIfNeeded(
            session: session, today: "2026-04-29",
            labels: labels, independentLabels: independentLabels
        )
        let midnight = TimerSession.startOfDay(for: "2026-04-29")!
        #expect(result!.newSession.activeIndependentTimers["independent_timer"] == midnight)
    }

    @Test("Stale session beyond maxRetroactiveDays is not returned for logging")
    func staleSessionBeyondLimit() {
        var svc = DayRolloverService()
        svc.maxRetroactiveDays = 2
        let session = TimerSession.fresh(day: "2026-04-01", labels: labels, independentLabels: independentLabels)
        let result = svc.rolloverIfNeeded(
            session: session, today: "2026-04-29",
            labels: labels, independentLabels: independentLabels
        )
        #expect(result != nil)
        #expect(result!.staleSessionToLog == nil)
        #expect(result!.newSession.day == "2026-04-29")
    }

    @Test("Flush accumulates time to end-of-day boundary on stale session")
    func flushToEndOfDayBoundary() {
        var session = TimerSession.fresh(day: "2026-04-28", labels: labels, independentLabels: independentLabels)
        let startTime = TimerSession.startOfDay(for: "2026-04-28")!.addingTimeInterval(3600 * 22)
        session.activeLabelId = "project_1"
        session.activeStartedAt = startTime
        session.accumulated["project_1"] = 0

        let result = service.rolloverIfNeeded(
            session: session, today: "2026-04-29",
            labels: labels, independentLabels: independentLabels
        )

        let expectedSeconds: TimeInterval = 3600 * 2
        let accumulated = result!.staleSessionToLog!.accumulated["project_1"]!
        #expect(abs(accumulated - expectedSeconds) < 1.0)
    }
}
