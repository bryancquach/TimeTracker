import Testing
import Foundation
@testable import TimeTracker

@Suite("LabelManager", .serialized)
@MainActor
struct LabelManagerTests {

    let manager: LabelManager

    init() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeTrackerTests-\(UUID().uuidString)")
        let persistence = PersistenceService(baseURL: tempDir)
        try? persistence.ensureDirectories()
        manager = LabelManager(
            labels: TimerLabel.defaults,
            independentLabels: IndependentTimerLabel.defaults,
            persistence: persistence
        )
    }

    // MARK: - Regular Labels

    @Test("addLabel appends a new label and returns it")
    func addLabel() throws {
        let count = manager.labels.count
        let label = try manager.addLabel(displayName: "New Task")
        #expect(manager.labels.count == count + 1)
        #expect(label.displayName == "New Task")
        #expect(manager.labels.last?.id == label.id)
    }

    @Test("addLabel throws for duplicate name")
    func addLabelDuplicate() throws {
        try manager.addLabel(displayName: "Alpha")
        #expect(throws: LabelError.self) {
            try manager.addLabel(displayName: "Alpha")
        }
    }

    @Test("updateLabel renames an existing label")
    func updateLabel() {
        let label = manager.labels[0]
        manager.updateLabel(id: label.id, newDisplayName: "Renamed")
        #expect(manager.labels[0].displayName == "Renamed")
        #expect(manager.labels[0].id == label.id)
    }

    @Test("updateLabel does nothing for unknown id")
    func updateLabelUnknown() {
        let before = manager.labels
        manager.updateLabel(id: "nonexistent", newDisplayName: "Oops")
        #expect(manager.labels.count == before.count)
    }

    @Test("deleteLabel removes the label")
    func deleteLabel() {
        let count = manager.labels.count
        let label = manager.labels[0]
        manager.deleteLabel(id: label.id)
        #expect(manager.labels.count == count - 1)
        #expect(!manager.labels.contains(where: { $0.id == label.id }))
    }

    @Test("deleteLabel calls preDeleteHook before clearing linked references")
    func deleteLabelPreDeleteHook() {
        var hookCalled = false
        let label = manager.labels[0]
        manager.deleteLabel(id: label.id) {
            hookCalled = true
        }
        #expect(hookCalled)
    }

    @Test("deleteLabel clears linkedLabelId on independent labels referencing the deleted label")
    func deleteLabelCascade() throws {
        let regularLabel = manager.labels[0]
        try manager.addIndependentLabel(displayName: "Linked", linkedLabelId: regularLabel.id)
        let indLabel = manager.independentLabels.last!
        #expect(indLabel.linkedLabelId == regularLabel.id)

        manager.deleteLabel(id: regularLabel.id)

        let updated = manager.independentLabels.first(where: { $0.id == indLabel.id })!
        #expect(updated.linkedLabelId == nil)
    }

    @Test("moveLabel reorders labels")
    func moveLabel() {
        let first = manager.labels[0]
        let second = manager.labels[1]
        manager.moveLabel(from: IndexSet(integer: 0), to: 2)
        #expect(manager.labels[0].id == second.id)
        #expect(manager.labels[1].id == first.id)
    }

    // MARK: - Independent Labels

    @Test("addIndependentLabel appends a new independent label and returns it")
    func addIndependentLabel() throws {
        let count = manager.independentLabels.count
        let label = try manager.addIndependentLabel(displayName: "My Timer")
        #expect(manager.independentLabels.count == count + 1)
        #expect(label.displayName == "My Timer")
    }

    @Test("addIndependentLabel with linked label id")
    func addIndependentLabelLinked() throws {
        let regularLabel = manager.labels[0]
        let label = try manager.addIndependentLabel(displayName: "Linked Timer", linkedLabelId: regularLabel.id)
        #expect(label.linkedLabelId == regularLabel.id)
    }

    @Test("addIndependentLabel throws for duplicate name")
    func addIndependentLabelDuplicate() throws {
        try manager.addIndependentLabel(displayName: "Beta")
        #expect(throws: LabelError.self) {
            try manager.addIndependentLabel(displayName: "Beta")
        }
    }

    @Test("updateIndependentLabel updates display name and linked label")
    func updateIndependentLabel() {
        let indLabel = manager.independentLabels[0]
        let regularLabel = manager.labels[0]
        manager.updateIndependentLabel(id: indLabel.id, newDisplayName: "Renamed", newLinkedLabelId: regularLabel.id)
        #expect(manager.independentLabels[0].displayName == "Renamed")
        #expect(manager.independentLabels[0].linkedLabelId == regularLabel.id)
    }

    @Test("deleteIndependentLabel removes the independent label")
    func deleteIndependentLabel() {
        let count = manager.independentLabels.count
        let indLabel = manager.independentLabels[0]
        manager.deleteIndependentLabel(id: indLabel.id)
        #expect(manager.independentLabels.count == count - 1)
        #expect(!manager.independentLabels.contains(where: { $0.id == indLabel.id }))
    }

    // MARK: - Bulk Operations

    @Test("replaceAll replaces both label arrays")
    func replaceAll() {
        let newLabels = [TimerLabel(id: "x", displayName: "X")]
        let newIndLabels = [IndependentTimerLabel(id: "y", displayName: "Y", linkedLabelId: nil)]
        manager.replaceAll(labels: newLabels, independentLabels: newIndLabels)
        #expect(manager.labels.count == 1)
        #expect(manager.labels[0].id == "x")
        #expect(manager.independentLabels.count == 1)
        #expect(manager.independentLabels[0].id == "y")
    }

    @Test("resetToDefaults restores default labels")
    func resetToDefaults() throws {
        try manager.addLabel(displayName: "Extra")
        manager.resetToDefaults()
        #expect(manager.labels.count == TimerLabel.defaults.count)
        #expect(manager.independentLabels.count == IndependentTimerLabel.defaults.count)
    }
}
