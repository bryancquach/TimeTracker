enum AppConstants {
    /// Standard work-day length used to compute adjusted hours.
    static let workDayHours: Double = 8.0

    /// Number of 1-second ticks between persist cycles.
    static let persistIntervalTicks: Int = 60

    /// Duration (seconds) the log-confirmation checkmark is shown.
    static let confirmationDisplaySeconds: Int = 2

    /// Maximum number of days a stale session can be retroactively logged.
    static let maxRetroactiveDays: Int = 14

    /// Default increment/decrement amount (minutes) for the +/− buttons.
    static let defaultTimeIncrementMinutes: Int = 6

    /// Allowed range (minutes) for the increment/decrement amount.
    static let timeIncrementMinutesRange: ClosedRange<Int> = 1...60

    /// UserDefaults key for the persisted time-increment setting (minutes).
    static let timeIncrementMinutesKey = "timeIncrementMinutes"

    /// Legacy UserDefaults key for the time-increment setting stored in hours.
    /// Read once to migrate existing settings to `timeIncrementMinutesKey`.
    static let legacyTimeIncrementHoursKey = "timeIncrementHours"

    /// UserDefaults key for the custom log output directory.
    static let logDirectoryKey = "logDirectoryPath"

    /// UserDefaults key for whether daily auto-stop is enabled.
    static let autoStopEnabledKey = "autoStopEnabled"

    /// UserDefaults key for the auto-stop time (minutes after local midnight).
    static let autoStopMinutesKey = "autoStopMinutes"

    /// Default auto-stop time: 5:00 PM.
    static let defaultAutoStopMinutes: Int = 17 * 60
}
