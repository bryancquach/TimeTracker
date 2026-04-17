import Testing
import Foundation
@testable import TimeTracker

@Suite("TimerSession")
struct TimerSessionTests {

    @Test("Fresh session initializes all labels with zero accumulation")
    func freshZeroAccumulation() {
        let session = TimerSession.fresh(day: "2026-01-01")
        for label in TimerLabel.defaults {
            #expect(session.accumulated[label.id] == 0)
        }
    }

    @Test("Fresh session has no active label")
    func freshNoActiveLabel() {
        let session = TimerSession.fresh(day: "2026-01-01")
        #expect(session.activeLabelId == nil)
        #expect(session.activeStartedAt == nil)
    }

    @Test("Fresh session initializes independent timer fields")
    func freshIndependentTimerFields() {
        let session = TimerSession.fresh(day: "2026-01-01")
        for label in IndependentTimerLabel.defaults {
            #expect(session.independentAccumulated[label.id] == 0)
        }
        #expect(session.activeIndependentTimers.isEmpty)
    }

    @Test("Fresh session day matches input")
    func freshDay() {
        let session = TimerSession.fresh(day: "2026-04-10")
        #expect(session.day == "2026-04-10")
    }

    @Test("todayString returns ISO 8601 date-only format")
    func todayStringFormat() {
        let today = TimerSession.todayString
        let regex = try! NSRegularExpression(pattern: #"^\d{4}-\d{2}-\d{2}$"#)
        let range = NSRange(today.startIndex..., in: today)
        #expect(regex.firstMatch(in: today, range: range) != nil)
    }

    @Test("todayString uses local timezone")
    func todayStringLocalTimezone() {
        let today = TimerSession.todayString
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        let expected = f.string(from: Date())
        #expect(today == expected)
    }

    @Test("dayString(for:) uses local timezone")
    func dayStringLocalTimezone() {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        let date = Date()
        let expected = f.string(from: date)
        #expect(TimerSession.dayString(for: date) == expected)
    }

    @Test("flush commits active timer delta into accumulated")
    func flushCommitsDelta() {
        var session = TimerSession.fresh(day: "2026-01-01")
        session.activeLabelId = "project_1"
        let start = Date()
        session.activeStartedAt = start

        let later = start.addingTimeInterval(100)
        session.flush(at: later)

        #expect(session.accumulated["project_1"]! >= 100)
        #expect(session.accumulated["project_1"]! < 100.1)
        #expect(session.activeStartedAt == later)
        #expect(session.activeLabelId == "project_1")
    }

    @Test("flush also flushes active independent timers")
    func flushIndependentTimers() {
        var session = TimerSession.fresh(day: "2026-01-01")
        let start = Date()
        session.activeIndependentTimers["independent_timer"] = start

        let later = start.addingTimeInterval(200)
        session.flush(at: later)

        #expect(session.independentAccumulated["independent_timer", default: 0] >= 200)
        #expect(session.independentAccumulated["independent_timer", default: 0] < 200.1)
        #expect(session.activeIndependentTimers["independent_timer"] == later)
    }

    @Test("flush is a no-op when no label is active")
    func flushNoOp() {
        var session = TimerSession.fresh(day: "2026-01-01")
        session.flush()
        for label in TimerLabel.defaults {
            #expect(session.accumulated[label.id] == 0)
        }
        for label in IndependentTimerLabel.defaults {
            #expect(session.independentAccumulated[label.id] == 0)
        }
    }

    @Test("endOfDay returns start of next day")
    func endOfDayHelper() {
        let endOfDay = TimerSession.endOfDay(for: "2026-04-10")
        let startOfNextDay = TimerSession.startOfDay(for: "2026-04-11")
        #expect(endOfDay != nil)
        #expect(startOfNextDay != nil)
        #expect(endOfDay == startOfNextDay)
    }

    @Test("startOfDay parses to midnight local time")
    func startOfDayHelper() {
        let date = TimerSession.startOfDay(for: "2026-04-10")
        #expect(date != nil)
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute, .second], from: date!)
        #expect(comps.hour == 0)
        #expect(comps.minute == 0)
        #expect(comps.second == 0)
    }

    @Test("daysBetween returns correct difference")
    func daysBetweenHelper() {
        let diff = TimerSession.daysBetween("2026-04-01", "2026-04-10")
        #expect(diff == 9)
    }

    @Test("daysBetween is symmetric")
    func daysBetweenSymmetric() {
        let a = TimerSession.daysBetween("2026-04-10", "2026-04-01")
        let b = TimerSession.daysBetween("2026-04-01", "2026-04-10")
        #expect(a == b)
    }

    @Test("Codable round-trip preserves all fields including independent timers")
    func codableRoundTrip() throws {
        var session = TimerSession.fresh(day: "2026-04-10")
        session.accumulated["project_1"] = 3600
        session.activeLabelId = "project_1"
        session.activeStartedAt = Date()
        session.independentAccumulated["independent_timer"] = 1800
        session.activeIndependentTimers["independent_timer"] = Date()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TimerSession.self, from: data)

        #expect(decoded.day == session.day)
        #expect(decoded.accumulated == session.accumulated)
        #expect(decoded.activeLabelId == session.activeLabelId)
        #expect(decoded.activeStartedAt != nil)
        #expect(decoded.independentAccumulated["independent_timer"] == 1800)
        #expect(decoded.activeIndependentTimers["independent_timer"] != nil)
    }
}
