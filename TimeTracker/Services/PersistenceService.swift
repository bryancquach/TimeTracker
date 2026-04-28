import Foundation

final class PersistenceService: SessionPersisting, @unchecked Sendable {

    static let encoder: JSONEncoder = JSONCoding.encoder
    static let decoder: JSONDecoder = JSONCoding.decoder

    private let baseURL: URL

    private var sessionURL: URL {
        baseURL.appendingPathComponent("session.json")
    }

    var logsDirectoryURL: URL {
        if let custom = UserDefaults.standard.string(forKey: AppConstants.logDirectoryKey), !custom.isEmpty {
            return URL(fileURLWithPath: custom, isDirectory: true)
        }
        return baseURL.appendingPathComponent("logs", isDirectory: true)
    }

    /// Create with a specific base directory.
    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    static let configFileURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("timetracker", isDirectory: true)
            .appendingPathComponent("config.json")
    }()

    private struct ConfigFile: Decodable {
        var timesheetDir: String?
    }

    static func resolvedBaseURL(configURL: URL = configFileURL, environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let config = try? Data(contentsOf: configURL),
           let parsed = try? decoder.decode(ConfigFile.self, from: config),
           let dir = parsed.timesheetDir, !dir.isEmpty {
            return URL(fileURLWithPath: dir, isDirectory: true)
        }
        if let envPath = environment["TIMESHEET_DIR"], !envPath.isEmpty {
            return URL(fileURLWithPath: envPath, isDirectory: true)
        }
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("TimeTracker", isDirectory: true)
    }

    convenience init() {
        self.init(baseURL: Self.resolvedBaseURL())
    }

    // MARK: - Directory Setup

    func ensureDirectories() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: baseURL, withIntermediateDirectories: true)
        try fm.createDirectory(at: logsDirectoryURL, withIntermediateDirectories: true)
    }

    // MARK: - Session

    func loadSession() throws -> TimerSession? {
        guard FileManager.default.fileExists(atPath: sessionURL.path) else { return nil }
        let data = try Data(contentsOf: sessionURL)
        return try Self.decoder.decode(TimerSession.self, from: data)
    }

    func saveSession(_ session: TimerSession) throws {
        let data = try Self.encoder.encode(session)
        try data.write(to: sessionURL, options: .atomic)
    }

    // MARK: - Labels

    private var labelsURL: URL {
        baseURL.appendingPathComponent("labels.json")
    }

    func loadLabels() throws -> [TimerLabel]? {
        guard FileManager.default.fileExists(atPath: labelsURL.path) else { return nil }
        let data = try Data(contentsOf: labelsURL)
        return try Self.decoder.decode([TimerLabel].self, from: data)
    }

    func saveLabels(_ labels: [TimerLabel]) throws {
        let data = try Self.encoder.encode(labels)
        try data.write(to: labelsURL, options: .atomic)
    }

    // MARK: - Independent Labels

    private var independentLabelsURL: URL {
        baseURL.appendingPathComponent("independent_labels.json")
    }

    func loadIndependentLabels() throws -> [IndependentTimerLabel]? {
        guard FileManager.default.fileExists(atPath: independentLabelsURL.path) else { return nil }
        let data = try Data(contentsOf: independentLabelsURL)
        return try Self.decoder.decode([IndependentTimerLabel].self, from: data)
    }

    func saveIndependentLabels(_ labels: [IndependentTimerLabel]) throws {
        let data = try Self.encoder.encode(labels)
        try data.write(to: independentLabelsURL, options: .atomic)
    }

    // MARK: - Logs

    func loadLog(for day: String) throws -> SessionLog? {
        let url = logsDirectoryURL.appendingPathComponent("\(day).json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try Self.decoder.decode(SessionLog.self, from: data)
    }

    func saveLog(_ log: SessionLog) throws {
        let data = try Self.encoder.encode(log)
        let url = logsDirectoryURL.appendingPathComponent("\(log.day).json")
        try data.write(to: url, options: .atomic)
    }

    func loadAllLogs() throws -> [SessionLog] {
        let fm = FileManager.default
        let logsURL = logsDirectoryURL
        guard fm.fileExists(atPath: logsURL.path) else { return [] }
        let files = try fm.contentsOfDirectory(at: logsURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        return files.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let log = try? Self.decoder.decode(SessionLog.self, from: data) else { return nil }
            return log
        }
    }

    func clearAllData() throws {
        let fm = FileManager.default
        for url in [sessionURL, labelsURL, independentLabelsURL] {
            if fm.fileExists(atPath: url.path) {
                try fm.removeItem(at: url)
            }
        }
        let logsURL = logsDirectoryURL
        if fm.fileExists(atPath: logsURL.path) {
            let files = try fm.contentsOfDirectory(at: logsURL, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
            for file in files {
                try fm.removeItem(at: file)
            }
        }
    }
}
