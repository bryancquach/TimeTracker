import Foundation
import os

@MainActor
@Observable
final class LabelManager {

    private static let log = Logger(subsystem: "com.timetracker", category: "LabelManager")

    private(set) var labels: [TimerLabel]
    private(set) var independentLabels: [IndependentTimerLabel]

    private let persistence: SessionWriting

    init(labels: [TimerLabel], independentLabels: [IndependentTimerLabel], persistence: SessionWriting) {
        self.labels = labels
        self.independentLabels = independentLabels
        self.persistence = persistence
    }

    // MARK: - Regular Labels

    @discardableResult
    func addLabel(displayName: String) throws -> TimerLabel {
        let existingIds = labels.map { $0.id }
        let id = try TimerLabel.generateId(from: displayName, existingIds: existingIds)
        let label = TimerLabel(id: id, displayName: displayName)
        labels.append(label)
        saveLabels()
        return label
    }

    func updateLabel(id: String, newDisplayName: String) {
        guard let index = labels.firstIndex(where: { $0.id == id }) else { return }
        labels[index].displayName = newDisplayName
        saveLabels()
    }

    func deleteLabel(id: String, preDeleteHook: (() -> Void)? = nil) {
        guard let index = labels.firstIndex(where: { $0.id == id }) else { return }
        labels.remove(at: index)

        preDeleteHook?()

        for i in independentLabels.indices where independentLabels[i].linkedLabelId == id {
            independentLabels[i].linkedLabelId = nil
        }
        saveIndependentLabels()
        saveLabels()
    }

    func moveLabel(from source: IndexSet, to destination: Int) {
        labels.move(fromOffsets: source, toOffset: destination)
        saveLabels()
    }

    // MARK: - Independent Labels

    @discardableResult
    func addIndependentLabel(displayName: String, linkedLabelId: TimerLabel.ID? = nil) throws -> IndependentTimerLabel {
        let existingIds = independentLabels.map { $0.id }
        let id = try IndependentTimerLabel.generateId(from: displayName, existingIds: existingIds)
        let label = IndependentTimerLabel(id: id, displayName: displayName, linkedLabelId: linkedLabelId)
        independentLabels.append(label)
        saveIndependentLabels()
        return label
    }

    func updateIndependentLabel(id: String, newDisplayName: String, newLinkedLabelId: TimerLabel.ID?) {
        guard let index = independentLabels.firstIndex(where: { $0.id == id }) else { return }
        independentLabels[index].displayName = newDisplayName
        independentLabels[index].linkedLabelId = newLinkedLabelId
        saveIndependentLabels()
    }

    func deleteIndependentLabel(id: String) {
        guard let index = independentLabels.firstIndex(where: { $0.id == id }) else { return }
        independentLabels.remove(at: index)
        saveIndependentLabels()
    }

    // MARK: - Bulk Operations

    func replaceAll(labels: [TimerLabel], independentLabels: [IndependentTimerLabel]) {
        self.labels = labels
        self.independentLabels = independentLabels
        saveLabels()
        saveIndependentLabels()
    }

    func resetToDefaults() {
        self.labels = TimerLabel.defaults
        self.independentLabels = IndependentTimerLabel.defaults
        saveLabels()
        saveIndependentLabels()
    }

    // MARK: - Persistence

    private func saveLabels() {
        do {
            try persistence.saveLabels(labels)
        } catch {
            Self.log.error("Failed to persist labels: \(error.localizedDescription)")
        }
    }

    private func saveIndependentLabels() {
        do {
            try persistence.saveIndependentLabels(independentLabels)
        } catch {
            Self.log.error("Failed to persist independent labels: \(error.localizedDescription)")
        }
    }
}
