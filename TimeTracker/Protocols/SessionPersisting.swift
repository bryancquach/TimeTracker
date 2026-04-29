import Foundation

protocol SessionReading: Sendable {
    func loadSession() throws -> TimerSession?
    func loadLabels() throws -> [TimerLabel]?
    func loadIndependentLabels() throws -> [IndependentTimerLabel]?
}

protocol SessionWriting: Sendable {
    func ensureDirectories() throws
    func saveSession(_ session: TimerSession) throws
    func saveLabels(_ labels: [TimerLabel]) throws
    func saveIndependentLabels(_ labels: [IndependentTimerLabel]) throws
    func clearAllData() throws
}

protocol LogPersisting: Sendable {
    var logsDirectoryURL: URL { get }
    func saveLog(_ log: SessionLog) throws
    func loadLog(for day: String) throws -> SessionLog?
    func loadAllLogs() throws -> [SessionLog]
}

protocol SessionPersisting: SessionReading, SessionWriting, LogPersisting {}
