import Foundation

struct IndependentTimerLabel: Identifiable, Codable, Hashable {
    let id: String
    var displayName: String
    var linkedLabelId: TimerLabel.ID?
}

extension IndependentTimerLabel {
    static let defaults: [IndependentTimerLabel] = [
        .init(id: "independent_timer", displayName: "Independent Timer", linkedLabelId: nil),
    ]

    static func generateId(from displayName: String, existingIds: [String] = []) throws -> String {
        try LabelIdGenerator.generateId(from: displayName, existingIds: existingIds)
    }
}
