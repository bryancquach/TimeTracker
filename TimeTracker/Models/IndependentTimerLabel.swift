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
        let base = displayName
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }

        let proposedBase = base.isEmpty ? "label" : base

        let hasConflict = existingIds.contains { existingId in
            existingId.hasPrefix(proposedBase + "_") || existingId == proposedBase
        }

        if hasConflict {
            throw TimerLabel.LabelError.duplicateLabel(displayName)
        }

        let suffix = UUID().uuidString.prefix(8).lowercased()
        return "\(proposedBase)_\(suffix)"
    }
}
