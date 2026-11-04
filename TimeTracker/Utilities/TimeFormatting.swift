import Foundation

enum TimeFormatting {
    /// Formats elapsed seconds as hours and whole minutes, e.g. "1h 05m".
    /// Minutes are truncated (a minute is shown only once fully elapsed).
    static func formattedHours(from seconds: TimeInterval) -> String {
        // Small epsilon guards against values like 0.1h * 3600 landing just under a minute boundary.
        let totalMinutes = max(0, Int((seconds + 1e-6) / 60))
        return String(format: "%dh %02dm", totalMinutes / 60, totalMinutes % 60)
    }
}
