import Foundation

struct DayRolloverResult {
    let newSession: TimerSession
    let staleSessionToLog: TimerSession?
}

struct DayRolloverService {
    var maxRetroactiveDays: Int = AppConstants.maxRetroactiveDays

    func rolloverIfNeeded(
        session: TimerSession,
        today: String,
        labels: [TimerLabel],
        independentLabels: [IndependentTimerLabel]
    ) -> DayRolloverResult? {
        guard session.day != today else { return nil }

        var stale = session
        let wasActive = stale.activeLabelId
        let wasIndependentTimersActive = stale.activeIndependentTimers

        if let endOfDay = TimerSession.endOfDay(for: stale.day) {
            stale.flush(at: endOfDay)
        } else {
            stale.flush()
        }

        stale.activeLabelId = nil
        stale.activeStartedAt = nil
        stale.activeIndependentTimers = [:]

        let withinLimit = TimerSession.daysBetween(stale.day, today)
            .map { $0 <= maxRetroactiveDays } ?? false
        let staleToLog: TimerSession? = withinLimit ? stale : nil

        var newSession = TimerSession.fresh(day: today, labels: labels, independentLabels: independentLabels)

        let midnight = TimerSession.startOfDay(for: today) ?? Date()
        if let activeId = wasActive {
            newSession.activeLabelId = activeId
            newSession.activeStartedAt = midnight
        }
        for (id, _) in wasIndependentTimersActive {
            newSession.activeIndependentTimers[id] = midnight
        }

        return DayRolloverResult(newSession: newSession, staleSessionToLog: staleToLog)
    }
}
