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

    @Test("resolvedBaseURL falls back to Application Support when no config or env var exists")
    func resolvedBaseURLDefault() throws {
        let bogusConfig = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString).json")
        let url = PersistenceService.resolvedBaseURL(configURL: bogusConfig, environment: [:])
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("TimeTracker", isDirectory: true)
        #expect(url == appSupport)
    }

    @Test("resolvedBaseURL uses config file timesheetDir when present")
    func resolvedBaseURLFromConfigFile() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeTrackerTests-config-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let configURL = tmpDir.appendingPathComponent("config.json")
        let targetDir = tmpDir.appendingPathComponent("my-timesheets")
        let json = """
        { "timesheetDir": "\(targetDir.path)" }
        """
        try json.data(using: .utf8)!.write(to: configURL, options: .atomic)

        let url = PersistenceService.resolvedBaseURL(configURL: configURL, environment: [:])
        #expect(url.path == targetDir.path)
    }

    @Test("resolvedBaseURL prefers config file over environment variable")
    func resolvedBaseURLConfigOverEnv() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeTrackerTests-priority-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let configURL = tmpDir.appendingPathComponent("config.json")
        let configDir = tmpDir.appendingPathComponent("from-config")
        let json = """
        { "timesheetDir": "\(configDir.path)" }
        """
        try json.data(using: .utf8)!.write(to: configURL, options: .atomic)

        let url = PersistenceService.resolvedBaseURL(
            configURL: configURL,
            environment: ["TIMESHEET_DIR": "/some/env/path"]
        )
        #expect(url.path == configDir.path)
    }

    @Test("resolvedBaseURL falls back to env var when config file has no timesheetDir")
    func resolvedBaseURLEnvFallback() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeTrackerTests-envfb-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let configURL = tmpDir.appendingPathComponent("config.json")
        try "{}".data(using: .utf8)!.write(to: configURL, options: .atomic)

        let url = PersistenceService.resolvedBaseURL(
            configURL: configURL,
            environment: ["TIMESHEET_DIR": "/env/path"]
        )
        #expect(url == URL(fileURLWithPath: "/env/path", isDirectory: true))
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

    @Test("loadLog returns nil for missing day")
    func loadLogMissing() throws {
        let (service, _) = try Self.makeTempService()
        let result = try service.loadLog(for: "2026-01-01")
        #expect(result == nil)
    }

    @Test("loadLog returns decoded log for existing day")
    func loadLogExists() throws {
        let (service, _) = try Self.makeTempService()
        let entry = SessionLogEntry(hours: 2.0, adjustedHours: 8.0)
        let log = SessionLog(
            day: "2026-04-15",
            totalHours: 2.0,
            entries: ["project_1": entry],
            loggedAt: Date()
        )
        try service.saveLog(log)

        let loaded = try service.loadLog(for: "2026-04-15")
        #expect(loaded != nil)
        #expect(loaded?.day == "2026-04-15")
        #expect(loaded?.totalHours == 2.0)
        #expect(loaded?.entries["project_1"]?.hours == 2.0)
    }

    @Test("loadLog throws for corrupt file")
    func loadLogCorrupt() throws {
        let (service, _) = try Self.makeTempService()
        let url = service.logsDirectoryURL.appendingPathComponent("2026-04-16.json")
        try "not valid json".data(using: .utf8)!.write(to: url, options: .atomic)

        #expect(throws: (any Error).self) {
            try service.loadLog(for: "2026-04-16")
        }
    }
}
