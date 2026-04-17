import Testing
import Foundation
@testable import TimeTracker

@Suite("PersistenceService", .serialized)
@MainActor
struct PersistenceServiceTests {

    private static func makeTempService() throws -> (PersistenceService, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeTrackerTests-\(UUID().uuidString)")
        let service = PersistenceService(baseURL: dir)
        try service.ensureDirectories()
        return (service, dir)
    }

    @Test("ensureDirectories creates base and logs directories")
    func ensureDirectories() throws {
        let (_, dir) = try Self.makeTempService()
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: dir.path))
        #expect(fm.fileExists(atPath: dir.appendingPathComponent("logs").path))
    }

    @Test("Save and load session round-trip")
    func saveLoadSession() throws {
        let (service, _) = try Self.makeTempService()
        var session = TimerSession.fresh(day: "2026-04-10")
        session.accumulated["project_1"] = 1234.5

        try service.saveSession(session)
        let loaded = try service.loadSession()

        #expect(loaded != nil)
        #expect(loaded?.day == "2026-04-10")
        #expect(loaded?.accumulated["project_1"] == 1234.5)
    }

    @Test("Load session returns nil when no file exists")
    func loadSessionNoFile() throws {
        let emptyDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeTrackerTests-empty-\(UUID().uuidString)")
        let service = PersistenceService(baseURL: emptyDir)
        try service.ensureDirectories()

        let loaded = try service.loadSession()
        #expect(loaded == nil)
    }

    @Test("Save and load labels round-trip")
    func saveLoadLabels() throws {
        let (service, _) = try Self.makeTempService()
        let labels: [TimerLabel] = [
            .init(id: "custom_1", displayName: "Custom One"),
            .init(id: "custom_2", displayName: "Custom Two"),
        ]
        try service.saveLabels(labels)
        let loaded = try service.loadLabels()

        #expect(loaded != nil)
        #expect(loaded?.count == 2)
        #expect(loaded?[0].id == "custom_1")
        #expect(loaded?[0].displayName == "Custom One")
        #expect(loaded?[1].id == "custom_2")
    }

    @Test("Load labels returns nil when no file exists")
    func loadLabelsNoFile() throws {
        let emptyDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeTrackerTests-empty-labels-\(UUID().uuidString)")
        let service = PersistenceService(baseURL: emptyDir)
        try service.ensureDirectories()

        let loaded = try service.loadLabels()
        #expect(loaded == nil)
    }

    @Test("Save and load independent labels round-trip")
    func saveLoadIndependentLabels() throws {
        let (service, _) = try Self.makeTempService()
        let labels: [IndependentTimerLabel] = [
            .init(id: "ind_1", displayName: "Ind One", linkedLabelId: "project_1"),
            .init(id: "ind_2", displayName: "Ind Two", linkedLabelId: nil),
        ]
        try service.saveIndependentLabels(labels)
        let loaded = try service.loadIndependentLabels()

        #expect(loaded != nil)
        #expect(loaded?.count == 2)
        #expect(loaded?[0].id == "ind_1")
        #expect(loaded?[0].displayName == "Ind One")
        #expect(loaded?[0].linkedLabelId == "project_1")
        #expect(loaded?[1].id == "ind_2")
        #expect(loaded?[1].linkedLabelId == nil)
    }

    @Test("Load independent labels returns nil when no file exists")
    func loadIndependentLabelsNoFile() throws {
        let emptyDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeTrackerTests-empty-ind-\(UUID().uuidString)")
        let service = PersistenceService(baseURL: emptyDir)
        try service.ensureDirectories()

        let loaded = try service.loadIndependentLabels()
        #expect(loaded == nil)
    }

    @Test("saveLog creates a correctly named log file")
    func saveLog() throws {
        let (service, dir) = try Self.makeTempService()
        let entry = SessionLogEntry(hours: 1.0, adjustedHours: 8.0)
        let log = SessionLog(
            day: "2026-04-10",
            totalHours: 1.0,
            entries: ["project_1": entry],
            loggedAt: Date()
        )

        try service.saveLog(log)

        let logFile = dir
            .appendingPathComponent("logs")
            .appendingPathComponent("2026-04-10.json")
        #expect(FileManager.default.fileExists(atPath: logFile.path))

        let data = try Data(contentsOf: logFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SessionLog.self, from: data)
        #expect(decoded.day == "2026-04-10")
        #expect(decoded.totalHours == 1.0)
    }
}
