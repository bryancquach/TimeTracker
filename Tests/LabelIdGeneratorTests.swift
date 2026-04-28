import Testing
import Foundation
@testable import TimeTracker

@Suite("LabelIdGenerator")
struct LabelIdGeneratorTests {

    @Test("generates ID with base derived from display name")
    func generateIdBasic() throws {
        let id = try LabelIdGenerator.generateId(from: "My Label")
        #expect(id.hasPrefix("my_label_"))
        #expect(id.count > "my_label_".count)
    }

    @Test("handles empty display name by using 'label' as base")
    func generateIdEmpty() throws {
        let id = try LabelIdGenerator.generateId(from: "")
        #expect(id.hasPrefix("label_"))
    }

    @Test("strips special characters from display name")
    func generateIdSpecialChars() throws {
        let id = try LabelIdGenerator.generateId(from: "Hello! @World#")
        #expect(id.hasPrefix("hello_world_"))
    }

    @Test("produces unique IDs for identical input")
    func generateIdUniqueness() throws {
        let id1 = try LabelIdGenerator.generateId(from: "Test")
        let id2 = try LabelIdGenerator.generateId(from: "Test")
        #expect(id1 != id2)
    }

    @Test("UUID suffix is 8 characters")
    func generateIdSuffixLength() throws {
        let id = try LabelIdGenerator.generateId(from: "Test")
        let suffix = String(id.dropFirst("test_".count))
        #expect(suffix.count == 8)
    }

    @Test("throws duplicateLabel when base conflicts with existing ID prefix")
    func generateIdConflictPrefix() throws {
        let existing = try LabelIdGenerator.generateId(from: "Project Alpha")
        #expect(throws: LabelError.self) {
            try LabelIdGenerator.generateId(from: "Project Alpha", existingIds: [existing])
        }
    }

    @Test("throws duplicateLabel when base exactly matches existing ID")
    func generateIdConflictExact() throws {
        #expect(throws: LabelError.self) {
            try LabelIdGenerator.generateId(from: "exact", existingIds: ["exact"])
        }
    }

    @Test("allows different base names without conflict")
    func generateIdNoConflict() throws {
        let existing = try LabelIdGenerator.generateId(from: "Project Alpha")
        let id = try LabelIdGenerator.generateId(from: "Project Beta", existingIds: [existing])
        #expect(id.hasPrefix("project_beta_"))
    }

    @Test("TimerLabel.generateId forwards to LabelIdGenerator")
    func timerLabelForwarding() throws {
        let id = try TimerLabel.generateId(from: "Forwarded")
        #expect(id.hasPrefix("forwarded_"))
    }

    @Test("IndependentTimerLabel.generateId forwards to LabelIdGenerator")
    func independentTimerLabelForwarding() throws {
        let id = try IndependentTimerLabel.generateId(from: "Forwarded")
        #expect(id.hasPrefix("forwarded_"))
    }

    @Test("LabelError provides descriptive error message")
    func labelErrorDescription() {
        let error = LabelError.duplicateLabel("Test")
        #expect(error.errorDescription?.contains("Test") == true)
        #expect(error.errorDescription?.contains("conflicts") == true)
    }
}
