import Foundation

struct TimerSession: Codable {
    /// Accumulated seconds per label id.
    var accumulated: [TimerLabel.ID: TimeInterval]

    /// Which label is currently active (nil = paused).
    var activeLabelId: TimerLabel.ID?

    /// Timestamp when the active timer last started (used to compute delta on restore).
    var activeStartedAt: Date?

    /// The calendar day these values belong to (ISO 8601 date string, e.g. "2026-04-10").
    var day: String

    /// Accumulated seconds per independent timer label id.
    var independentAccumulated: [IndependentTimerLabel.ID: TimeInterval]

    /// Currently running independent timers mapped to their start time.
    var activeIndependentTimers: [IndependentTimerLabel.ID: Date]

    init(accumulated: [TimerLabel.ID: TimeInterval],
         activeLabelId: TimerLabel.ID?,
         activeStartedAt: Date?,
         day: String,
         independentAccumulated: [IndependentTimerLabel.ID: TimeInterval] = [:],
         activeIndependentTimers: [IndependentTimerLabel.ID: Date] = [:]) {
        self.accumulated = accumulated
        self.activeLabelId = activeLabelId
        self.activeStartedAt = activeStartedAt
        self.day = day
        self.independentAccumulated = independentAccumulated
        self.activeIndependentTimers = activeIndependentTimers
    }

    /// Commit the delta from the active timer into `accumulated` and reset `activeStartedAt`.
    /// Also flushes all active independent timers.
    mutating func flush(at now: Date = Date()) {
        if let activeId = activeLabelId, let startedAt = activeStartedAt {
            accumulated[activeId, default: 0] += now.timeIntervalSince(startedAt)
            activeStartedAt = now
        }
        for (id, startedAt) in activeIndependentTimers {
            independentAccumulated[id, default: 0] += now.timeIntervalSince(startedAt)
            activeIndependentTimers[id] = now
        }
    }

    static func fresh(day: String, labels: [TimerLabel] = TimerLabel.defaults,
                      independentLabels: [IndependentTimerLabel] = IndependentTimerLabel.defaults) -> TimerSession {
        TimerSession(
            accumulated: Dictionary(uniqueKeysWithValues: labels.map { ($0.id, 0.0) }),
            activeLabelId: nil,
            activeStartedAt: nil,
            day: day,
            independentAccumulated: Dictionary(uniqueKeysWithValues: independentLabels.map { ($0.id, 0.0) }),
            activeIndependentTimers: [:]
        )
    }

    // MARK: - Date Helpers

    static func dayString(for date: Date) -> String {
        DayFormatter.dayString(for: date)
    }

    static var todayString: String { dayString(for: Date()) }

    static func startOfDay(for dayString: String) -> Date? {
        DayFormatter.startOfDay(for: dayString)
    }

    /// Returns start of the next day (midnight boundary) for the given day string.
    static func endOfDay(for dayString: String) -> Date? {
        guard let start = startOfDay(for: dayString) else { return nil }
        return Calendar.current.date(byAdding: .day, value: 1, to: start)
    }

    /// Number of calendar days between two day strings. Returns nil if either is unparseable.
    static func daysBetween(_ dayA: String, _ dayB: String) -> Int? {
        guard let a = startOfDay(for: dayA), let b = startOfDay(for: dayB) else { return nil }
        return Calendar.current.dateComponents([.day], from: a, to: b).day.map(abs)
    }
}
