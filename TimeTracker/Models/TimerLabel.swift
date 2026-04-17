import Foundation

struct TimerLabel: Identifiable, Codable, Hashable {
    let id: String
    var displayName: String
}

// Default label definitions used when no custom labels have been saved.
extension TimerLabel {
    static let defaults: [TimerLabel] = [
        .init(id: "project_1",              displayName: "Project 1"),
        .init(id: "project_2",              displayName: "Project 2"),
        .init(id: "internal_training",      displayName: "Internal Training"),
        .init(id: "company_town_hall",      displayName: "Town Hall Meeting"),
    ]

    /// Generate a unique ID from a display name.
    /// - Parameter displayName: The display name to generate an ID from
    /// - Parameter existingIds: Array of existing label IDs to check for conflicts
    /// - Throws: An error if the base name conflicts with an existing label
    /// - Returns: A unique ID string
    static func generateId(from displayName: String, existingIds: [String] = []) throws -> String {
        let base = displayName
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }

        let proposedBase = base.isEmpty ? "label" : base

        // Check if any existing ID starts with this base
        let hasConflict = existingIds.contains { existingId in
            existingId.hasPrefix(proposedBase + "_") || existingId == proposedBase
        }

        if hasConflict {
            throw LabelError.duplicateLabel(displayName)
        }

        let suffix = UUID().uuidString.prefix(8).lowercased()
        return "\(proposedBase)_\(suffix)"
    }

    public enum LabelError: LocalizedError {
        case duplicateLabel(String)

        var errorDescription: String? {
            switch self {
            case .duplicateLabel(let name):
                return "The label '\(name)' conflicts with an existing label. Please try a different label name."
            }
        }
    }
}
