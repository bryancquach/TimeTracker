import Testing
import Foundation
@testable import TimeTracker

@Suite("TimerLabel")
struct TimerLabelTests {

    @Test("All labels have unique IDs")
    func uniqueIds() {
        let ids = TimerLabel.defaults.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("All labels have non-empty display names")
    func displayNames() {
        for label in TimerLabel.defaults {
            #expect(!label.displayName.isEmpty)
        }
    }

    @Test("Codable round-trip preserves values")
    func codableRoundTrip() throws {
        let original = TimerLabel(id: "test_id", displayName: "Test Label")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TimerLabel.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.displayName == original.displayName)
    }

    @Test("Equatable and Hashable")
    func equatableHashable() {
        let a = TimerLabel(id: "x", displayName: "X")
        let b = TimerLabel(id: "x", displayName: "X")
        let c = TimerLabel(id: "y", displayName: "Y")
        #expect(a == b)
        #expect(a != c)
        let set: Set<TimerLabel> = [a, b, c]
        #expect(set.count == 2)
    }

    @Test("generateId produces non-empty ID with UUID suffix")
    func generateId() throws {
        let id = try TimerLabel.generateId(from: "My Label")
        #expect(id.hasPrefix("my_label_"))
        #expect(id.count > "my_label_".count)
    }

    @Test("generateId handles empty display name")
    func generateIdEmpty() throws {
        let id = try TimerLabel.generateId(from: "")
        #expect(id.hasPrefix("label_"))
        #expect(!id.isEmpty)
    }

    @Test("generateId produces unique IDs for same input")
    func generateIdUnique() throws {
        let id1 = try TimerLabel.generateId(from: "Test")
        let id2 = try TimerLabel.generateId(from: "Test")
        #expect(id1 != id2)
    }

    @Test("generateId throws error when base name conflicts")
    func generateIdConflict() throws {
        let existingId = try TimerLabel.generateId(from: "Project Alpha")
        #expect(throws: TimerLabel.LabelError.self) {
            try TimerLabel.generateId(from: "Project Alpha", existingIds: [existingId])
        }
    }

    @Test("generateId allows different base names")
    func generateIdNonConflict() throws {
        let existingId = try TimerLabel.generateId(from: "Project Alpha")
        let newId = try TimerLabel.generateId(from: "Project Beta", existingIds: [existingId])
        #expect(newId.hasPrefix("project_beta_"))
    }
}
