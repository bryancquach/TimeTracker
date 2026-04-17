enum AppConstants {
    /// Standard work-day length used to compute adjusted hours.
    static let workDayHours: Double = 8.0

    /// Number of 1-second ticks between persist cycles.
    static let persistIntervalTicks: Int = 60

    /// Duration (seconds) the log-confirmation checkmark is shown.
    static let confirmationDisplaySeconds: Int = 2

    /// Maximum number of days a stale session can be retroactively logged.
    static let maxRetroactiveDays: Int = 14

    /// Default increment/decrement amount (hours) for the +/− buttons.
    static let defaultTimeIncrementHours: Double = 0.1

    /// UserDefaults key for the persisted time-increment setting.
    static let timeIncrementKey = "timeIncrementHours"

    /// UserDefaults key for the custom log output directory.
    static let logDirectoryKey = "logDirectoryPath"
}
