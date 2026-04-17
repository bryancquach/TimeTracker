import Testing
import Foundation
@testable import TimeTracker

@Suite("SessionLog")
struct SessionLogTests {

    @Test("TimeInterval.asHours converts correctly")
    func asHours() {
        #expect((3600.0).asHours == 1.0)
        #expect((7200.0).asHours == 2.0)
        #expect((1800.0).asHours == 0.5)
        #expect((0.0).asHours == 0.0)
    }

    @Test("SessionLogEntry stores hours directly")
    func storedHours() {
        let entry = SessionLogEntry(hours: 1.0, adjustedHours: 4.0)
        #expect(entry.hours == 1.0)
        #expect(entry.adjustedHours == 4.0)
    }

    @Test("SessionLogEntry encodes hours and adjustedHours without seconds")
    func encodesHours() throws {
        let entry = SessionLogEntry(hours: 2.0, adjustedHours: 4.0)
        let data = try JSONEncoder().encode(entry)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["hours"] as? Double == 2.0)
        #expect(json["adjustedHours"] as? Double == 4.0)
        #expect(json["seconds"] == nil)
    }

    @Test("SessionLog Codable round-trip with independent timer entries")
    func sessionLogRoundTrip() throws {
        let entry = SessionLogEntry(hours: 1.0, adjustedHours: 8.0)
        let log = SessionLog(
            day: "2026-04-10",
            totalHours: 1.0,
            entries: ["project_1": entry],
            loggedAt: Date(),
            independentTimerEntries: ["independent_timer": 0.5]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(log)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SessionLog.self, from: data)

        #expect(decoded.day == "2026-04-10")
        #expect(decoded.totalHours == 1.0)
        #expect(decoded.entries["project_1"]?.hours == 1.0)
        #expect(decoded.entries["project_1"]?.adjustedHours == 8.0)
        #expect(decoded.independentTimerEntries["independent_timer"] == 0.5)
        #expect(decoded.totalIndependentTimerHours == 0.5)
    }

}
