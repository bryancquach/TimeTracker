import Foundation

/// Computes the daily auto-stop cutoff from a configured local time of day.
struct AutoStopSchedule {
    /// Cutoff time expressed as minutes after local midnight (0..<1440).
    var minutesAfterMidnight: Int
    var calendar: Calendar = .current

    /// The cutoff moment on the calendar day containing `date`.
    func cutoff(onDayOf date: Date) -> Date? {
        let minutes = Self.clamp(minutesAfterMidnight)
        return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: date)
    }

    /// The first cutoff strictly after `start` and at or before `end`, or nil if none was crossed.
    func firstCutoff(after start: Date, through end: Date) -> Date? {
        guard start < end, var candidate = cutoff(onDayOf: start) else { return nil }
        if candidate <= start {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: start),
                  let next = cutoff(onDayOf: nextDay) else { return nil }
            candidate = next
        }
        return candidate <= end ? candidate : nil
    }

    static func clamp(_ minutes: Int) -> Int {
        min(24 * 60 - 1, max(0, minutes))
    }
}
