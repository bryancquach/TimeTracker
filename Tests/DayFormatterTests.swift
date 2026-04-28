import Testing
import Foundation
@testable import TimeTracker

@Suite("DayFormatter")
struct DayFormatterTests {

    @Test("dayString formats date as yyyy-MM-dd")
    func dayStringFormat() {
        let components = DateComponents(
            calendar: Calendar.current,
            timeZone: .current,
            year: 2026, month: 4, day: 15, hour: 14, minute: 30
        )
        let date = components.date!
        #expect(DayFormatter.dayString(for: date) == "2026-04-15")
    }

    @Test("startOfDay parses yyyy-MM-dd to midnight")
    func startOfDayParsing() {
        let date = DayFormatter.startOfDay(for: "2026-04-15")
        #expect(date != nil)
        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: date!)
        #expect(comps.hour == 0)
        #expect(comps.minute == 0)
        #expect(comps.second == 0)
    }

    @Test("round-trip: dayString then startOfDay preserves the day")
    func roundTrip() {
        let components = DateComponents(
            calendar: Calendar.current,
            timeZone: .current,
            year: 2026, month: 12, day: 31, hour: 23, minute: 59
        )
        let original = components.date!
        let dayStr = DayFormatter.dayString(for: original)
        let parsed = DayFormatter.startOfDay(for: dayStr)
        #expect(parsed != nil)
        #expect(DayFormatter.dayString(for: parsed!) == dayStr)
    }

    @Test("startOfDay returns nil for invalid input")
    func startOfDayInvalid() {
        #expect(DayFormatter.startOfDay(for: "not-a-date") == nil)
        #expect(DayFormatter.startOfDay(for: "") == nil)
    }

    @Test("TimerSession.dayString delegates to DayFormatter")
    func timerSessionDelegation() {
        let date = Date()
        #expect(TimerSession.dayString(for: date) == DayFormatter.dayString(for: date))
    }

    @Test("TimerSession.startOfDay delegates to DayFormatter")
    func timerSessionStartOfDayDelegation() {
        let ds = "2026-06-15"
        #expect(TimerSession.startOfDay(for: ds) == DayFormatter.startOfDay(for: ds))
    }
}
