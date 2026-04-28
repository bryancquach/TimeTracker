import Foundation

public enum LabelError: LocalizedError {
    case duplicateLabel(String)

    public var errorDescription: String? {
        switch self {
        case .duplicateLabel(let name):
            return "The label '\(name)' conflicts with an existing label. Please try a different label name."
        }
    }
}

enum LabelIdGenerator {
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
            throw LabelError.duplicateLabel(displayName)
        }

        let suffix = UUID().uuidString.prefix(8).lowercased()
        return "\(proposedBase)_\(suffix)"
    }
}
