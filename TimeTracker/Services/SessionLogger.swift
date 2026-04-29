import Foundation
import os

struct SessionLogger: Sendable {

    private static let log = Logger(subsystem: "com.timetracker", category: "SessionLogger")
    private let persistence: LogPersisting

    init(persistence: LogPersisting) {
        self.persistence = persistence
    }

    func buildLog(from session: TimerSession, labels: [TimerLabel],
                  independentLabels: [IndependentTimerLabel] = []) -> SessionLog {
        let labelIds = Set(labels.map(\.id))
        let allIds = labelIds.union(session.accumulated.keys)
        let totalHours = allIds.reduce(0.0) { $0 + session.accumulated[$1, default: 0] }.asHours
        var entries: [TimerLabel.ID: SessionLogEntry] = [:]
        for id in allIds {
            let hours = session.accumulated[id, default: 0].asHours
            let adjusted = totalHours > 0 ? (hours / totalHours) * AppConstants.workDayHours : 0.0
            entries[id] = SessionLogEntry(hours: hours, adjustedHours: adjusted)
        }

        var independentTimerEntries: [IndependentTimerLabel.ID: Double] = [:]
        let independentIds = Set(independentLabels.map(\.id)).union(session.independentAccumulated.keys)
        for id in independentIds {
            independentTimerEntries[id] = session.independentAccumulated[id, default: 0].asHours
        }

        return SessionLog(
            day: session.day,
            totalHours: totalHours,
            entries: entries,
            loggedAt: Date(),
            independentTimerEntries: independentTimerEntries
        )
    }

    func log(_ session: TimerSession, labels: [TimerLabel],
             independentLabels: [IndependentTimerLabel] = []) {
        let log = buildLog(from: session, labels: labels, independentLabels: independentLabels)
        do {
            try persistence.saveLog(log)
        } catch {
            Self.log.error("Failed to save log: \(error.localizedDescription)")
        }
    }

    func log(_ session: TimerSession, labels: [TimerLabel],
             independentLabels: [IndependentTimerLabel] = [], to url: URL) {
        let log = buildLog(from: session, labels: labels, independentLabels: independentLabels)
        do {
            let data = try JSONCoding.encoder.encode(log)
            try data.write(to: url, options: .atomic)
        } catch {
            Self.log.error("Failed to write log to \(url.path): \(error.localizedDescription)")
        }
    }

    func recalculateLogFile(at url: URL) throws {
        let originalData = try Data(contentsOf: url)
        do {
            let log = try JSONCoding.decoder.decode(SessionLog.self, from: originalData)
            let recalculated = log.recalculated()
            let newData = try JSONCoding.encoder.encode(recalculated)
            try newData.write(to: url, options: .atomic)
        } catch {
            try? originalData.write(to: url, options: .atomic)
            throw error
        }
    }

}
