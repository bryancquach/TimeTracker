import Foundation

extension TimeInterval {
    /// Convert seconds to hours.
    var asHours: Double { self / 3600.0 }
}

extension Double {
    /// Round to 2 decimal places for logging.
    var roundedToTwoDecimals: Double {
        (self * 100).rounded() / 100
    }
}

struct SessionLogEntry: Codable {
    let hours: Double
    let adjustedHours: Double

    enum CodingKeys: String, CodingKey {
        case hours, adjustedHours
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(hours.roundedToTwoDecimals, forKey: .hours)
        try c.encode(adjustedHours.roundedToTwoDecimals, forKey: .adjustedHours)
    }
}

struct SessionLog: Codable {
    let day: String
    let totalHours: Double
    let entries: [TimerLabel.ID: SessionLogEntry]
    let loggedAt: Date
    let independentTimerEntries: [IndependentTimerLabel.ID: Double]

    var totalIndependentTimerHours: Double {
        independentTimerEntries.values.reduce(0.0, +)
    }

    enum CodingKeys: String, CodingKey {
        case day, totalHours, entries, loggedAt
        case independentTimerEntries
    }

    init(day: String, totalHours: Double, entries: [TimerLabel.ID: SessionLogEntry],
         loggedAt: Date, independentTimerEntries: [IndependentTimerLabel.ID: Double] = [:]) {
        self.day = day
        self.totalHours = totalHours
        self.entries = entries
        self.loggedAt = loggedAt
        self.independentTimerEntries = independentTimerEntries
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decode(String.self, forKey: .day)
        totalHours = try c.decode(Double.self, forKey: .totalHours)
        entries = try c.decode([TimerLabel.ID: SessionLogEntry].self, forKey: .entries)
        loggedAt = try c.decode(Date.self, forKey: .loggedAt)
        independentTimerEntries = (try? c.decode([IndependentTimerLabel.ID: Double].self, forKey: .independentTimerEntries)) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(day, forKey: .day)
        try c.encode(totalHours.roundedToTwoDecimals, forKey: .totalHours)
        try c.encode(entries, forKey: .entries)
        try c.encode(loggedAt, forKey: .loggedAt)
        let rounded = independentTimerEntries.mapValues { $0.roundedToTwoDecimals }
        try c.encode(rounded, forKey: .independentTimerEntries)
    }

    func recalculated() -> SessionLog {
        let totalHours = entries.values.reduce(0.0) { $0 + $1.hours }
        let newEntries = entries.mapValues { entry in
            SessionLogEntry(
                hours: entry.hours,
                adjustedHours: totalHours > 0
                    ? (entry.hours / totalHours) * AppConstants.workDayHours
                    : 0.0
            )
        }
        return SessionLog(
            day: day,
            totalHours: totalHours,
            entries: newEntries,
            loggedAt: loggedAt,
            independentTimerEntries: independentTimerEntries
        )
    }
}
