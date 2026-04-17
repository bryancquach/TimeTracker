import Testing
import Foundation
@testable import TimeTracker

@Suite("SessionLogger", .serialized)
struct SessionLoggerTests {

    private func makeLogger() throws -> (SessionLogger, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeTrackerTests-\(UUID().uuidString)")
        let persistence = PersistenceService(baseURL: dir)
        try persistence.ensureDirectories()
        return (SessionLogger(persistence: persistence), dir)
    }

    @Test("buildLog computes correct totalHours and entries")
    func buildLog() throws {
        let (logger, _) = try makeLogger()
        var session = TimerSession.fresh(day: "2026-04-10")
        session.accumulated["project_1"] = 3600
        session.accumulated["project_2"] = 3600

        let log = logger.buildLog(from: session, labels: TimerLabel.defaults)

        #expect(log.day == "2026-04-10")
        #expect(log.totalHours == 2.0)
        #expect(log.entries["project_1"]?.hours == 1.0)
        #expect(log.entries["project_2"]?.hours == 1.0)
    }

    @Test("buildLog adjusts hours proportionally to an 8-hour day")
    func buildLogAdjustedHours() throws {
        let (logger, _) = try makeLogger()
        var session = TimerSession.fresh(day: "2026-04-10")
        session.accumulated["project_1"] = 3600
        session.accumulated["project_2"] = 3600

        let log = logger.buildLog(from: session, labels: TimerLabel.defaults)

        #expect(log.entries["project_1"]?.adjustedHours == 4.0)
        #expect(log.entries["project_2"]?.adjustedHours == 4.0)
        #expect(log.entries["internal_training"]?.adjustedHours == 0.0)
    }

    @Test("buildLog handles zero total seconds")
    func buildLogZero() throws {
        let (logger, _) = try makeLogger()
        let session = TimerSession.fresh(day: "2026-04-10")
        let log = logger.buildLog(from: session, labels: TimerLabel.defaults)

        #expect(log.totalHours == 0.0)
        for entry in log.entries.values {
            #expect(entry.adjustedHours == 0.0)
        }
    }

    @Test("buildLog includes independent timer entries from session")
    func buildLogIndependentTimerEntries() throws {
        let (logger, _) = try makeLogger()
        var session = TimerSession.fresh(day: "2026-04-10")
        session.accumulated["project_1"] = 3600
        session.independentAccumulated["independent_timer"] = 1800

        let log = logger.buildLog(from: session, labels: TimerLabel.defaults,
                                  independentLabels: IndependentTimerLabel.defaults)

        #expect(log.independentTimerEntries["independent_timer"] == 0.5)
        #expect(log.totalHours == 1.0)
    }

    @Test("buildLog excludes independent timer from totals and adjusted hours")
    func buildLogIndependentTimerExcludedFromTotals() throws {
        let (logger, _) = try makeLogger()
        var session = TimerSession.fresh(day: "2026-04-10")
        session.accumulated["project_1"] = 3600
        session.independentAccumulated["independent_timer"] = 7200

        let log = logger.buildLog(from: session, labels: TimerLabel.defaults,
                                  independentLabels: IndependentTimerLabel.defaults)

        #expect(log.totalHours == 1.0)
        #expect(log.entries["project_1"]?.adjustedHours == 8.0)
    }

    @Test("log saves to default persistence location")
    func logDefault() throws {
        let (logger, dir) = try makeLogger()
        var session = TimerSession.fresh(day: "2026-04-10")
        session.accumulated["project_1"] = 3600

        logger.log(session, labels: TimerLabel.defaults)

        let logFile = dir.appendingPathComponent("logs/2026-04-10.json")
        #expect(FileManager.default.fileExists(atPath: logFile.path))
    }

    @Test("log(to:) writes valid JSON to specified URL")
    func logToURL() throws {
        let (logger, _) = try makeLogger()
        var session = TimerSession.fresh(day: "2026-04-10")
        session.accumulated["project_1"] = 3600

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-log-\(UUID().uuidString).json")
        logger.log(session, labels: TimerLabel.defaults, to: tempFile)

        let data = try Data(contentsOf: tempFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let log = try decoder.decode(SessionLog.self, from: data)
        #expect(log.entries["project_1"]?.hours == 1.0)

        try? FileManager.default.removeItem(at: tempFile)
    }

    @Test("logged values are rounded to 2 decimal places in JSON")
    func loggedValuesRoundedToTwoDecimalsInJSON() throws {
        let (logger, _) = try makeLogger()
        var session = TimerSession.fresh(day: "2026-04-14")
        session.accumulated["project_1"] = 1234
        session.accumulated["project_2"] = 5678
        session.independentAccumulated["independent_timer"] = 999

        let log = logger.buildLog(from: session, labels: TimerLabel.defaults,
                                  independentLabels: IndependentTimerLabel.defaults)

        let data = try PersistenceService.encoder.encode(log)
        let jsonString = String(data: data, encoding: .utf8)!

        #expect(jsonString.contains("\"totalHours\" : 1.92"))
        #expect(jsonString.contains("\"independent_timer\" : 0.28"))
        #expect(jsonString.contains("\"hours\" : 0.34"))
        #expect(jsonString.contains("\"hours\" : 1.58"))
        #expect(jsonString.contains("\"adjustedHours\" : 1.43"))
        #expect(jsonString.contains("\"adjustedHours\" : 6.57"))
    }
}
