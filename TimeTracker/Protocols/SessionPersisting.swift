import Foundation

protocol SessionPersisting: Sendable {
    var logsDirectoryURL: URL { get }
    func ensureDirectories() throws
    func loadSession() throws -> TimerSession?
    func saveSession(_ session: TimerSession) throws
    func saveLog(_ log: SessionLog) throws
    func loadLabels() throws -> [TimerLabel]?
    func saveLabels(_ labels: [TimerLabel]) throws
    func loadIndependentLabels() throws -> [IndependentTimerLabel]?
    func saveIndependentLabels(_ labels: [IndependentTimerLabel]) throws
    func loadAllLogs() throws -> [SessionLog]
    func clearAllData() throws
}
