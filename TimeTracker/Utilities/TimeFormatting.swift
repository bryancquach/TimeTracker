import Foundation

enum TimeFormatting {
    static func formattedHours(from seconds: TimeInterval) -> String {
        String(format: "%.2fh", seconds.asHours)
    }
}
