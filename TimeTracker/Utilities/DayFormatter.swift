import Foundation

enum DayFormatter {
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    static func dayString(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func startOfDay(for dayString: String) -> Date? {
        dayFormatter.date(from: dayString)
    }
}
