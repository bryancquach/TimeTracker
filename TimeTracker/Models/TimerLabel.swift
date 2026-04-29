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
}
