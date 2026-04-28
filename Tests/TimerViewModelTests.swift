import Testing
import Foundation
@testable import TimeTracker

@Suite("TimerViewModel", .serialized)
@MainActor
struct TimerViewModelTests {

    let viewModel: TimerViewModel

    init() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeTrackerTests-\(UUID().uuidString)")
        let persistence = PersistenceService(baseURL: tempDir)
        viewModel = TimerViewModel(persistence: persistence)
    }

    // MARK: - Initial State

    @Test("Initial state has no active label")
    func initialState() {
        #expect(viewModel.session.activeLabelId == nil)
        #expect(viewModel.session.activeStartedAt == nil)
    }

    @Test("Initial state has no active independent timers")
    func initialIndependentTimerState() {
        #expect(viewModel.session.activeIndependentTimers.isEmpty)
        for label in viewModel.independentLabels {
            #expect(viewModel.isIndependentTimerActive(label.id) == false)
            #expect(viewModel.session.independentAccumulated[label.id] == 0)
        }
    }

    // MARK: - Tap

    @Test("Tap activates a label")
    func tapActivates() {
        let label = TimerLabel.defaults[0]
        viewModel.tap(label)
        #expect(viewModel.session.activeLabelId == label.id)
        #expect(viewModel.session.activeStartedAt != nil)
    }

    @Test("Tap same label toggles it off")
    func tapTogglesOff() {
        let label = TimerLabel.defaults[0]
        viewModel.tap(label)
        viewModel.tap(label)
        #expect(viewModel.session.activeLabelId == nil)
        #expect(viewModel.session.activeStartedAt == nil)
    }

    @Test("Tap different label switches active label")
    func tapSwitches() {
        let label1 = TimerLabel.defaults[0]
        let label2 = TimerLabel.defaults[1]
        viewModel.tap(label1)
        viewModel.tap(label2)
        #expect(viewModel.session.activeLabelId == label2.id)
    }

    @Test("Tap flushes accumulated time from previous active label")
    func tapFlushes() {
        let label1 = TimerLabel.defaults[0]
        let label2 = TimerLabel.defaults[1]
        viewModel.session.accumulated[label1.id] = 100
        viewModel.session.activeLabelId = label1.id
        viewModel.session.activeStartedAt = Date()

        viewModel.tap(label2)

        #expect(viewModel.session.accumulated[label1.id, default: 0] >= 100)
        #expect(viewModel.session.activeLabelId == label2.id)
    }

    // MARK: - Accumulated Seconds

    @Test("accumulatedSeconds returns stored value for inactive label")
    func accumulatedSecondsInactive() {
        viewModel.session.accumulated["project_1"] = 3600
        let result = viewModel.accumulatedSeconds(for: "project_1")
        #expect(result == 3600)
    }

    @Test("accumulatedSeconds includes live elapsed for active label")
    func accumulatedSecondsActive() {
        let label = TimerLabel.defaults.first { $0.id == "project_1" }!
        viewModel.tap(label)
        let result = viewModel.accumulatedSeconds(for: "project_1")
        #expect(result >= -0.1)
        #expect(result < 1.0)
    }

    // MARK: - Formatting

    @Test("formattedHours returns correct format")
    func formattedHours() {
        viewModel.session.accumulated["project_1"] = 3600
        let result = viewModel.formattedHours(for: "project_1")
        #expect(result == "1.00h")
    }

    @Test("formattedHours for zero seconds")
    func formattedHoursZero() {
        let result = viewModel.formattedHours(for: "project_1")
        #expect(result == "0.00h")
    }

    @Test("totalFormattedHours sums all labels")
    func totalFormattedHours() {
        viewModel.session.accumulated["project_1"] = 3600
        viewModel.session.accumulated["project_2"] = 3600
        let result = viewModel.totalFormattedHours
        #expect(result == "2.00h")
    }

    // MARK: - Independent Timers

    @Test("tapIndependentTimer activates independent timer")
    func tapIndependentTimerActivates() {
        let indLabel = viewModel.independentLabels[0]
        viewModel.tapIndependentTimer(indLabel)
        #expect(viewModel.isIndependentTimerActive(indLabel.id) == true)
        #expect(viewModel.session.activeIndependentTimers[indLabel.id] != nil)
    }

    @Test("tapIndependentTimer toggles independent timer off")
    func tapIndependentTimerTogglesOff() {
        let indLabel = viewModel.independentLabels[0]
        viewModel.tapIndependentTimer(indLabel)
        viewModel.tapIndependentTimer(indLabel)
        #expect(viewModel.isIndependentTimerActive(indLabel.id) == false)
        #expect(viewModel.session.activeIndependentTimers[indLabel.id] == nil)
    }

    @Test("Linked independent timer force-switches regular timer")
    func linkedTimerForceSwitchesRegular() throws {
        let regularLabel = viewModel.labels[1]
        try viewModel.addIndependentLabel(displayName: "Linked Timer", linkedLabelId: regularLabel.id)
        let linkedIndLabel = viewModel.independentLabels.last!

        viewModel.tap(viewModel.labels[0])
        #expect(viewModel.session.activeLabelId == viewModel.labels[0].id)

        viewModel.tapIndependentTimer(linkedIndLabel)
        #expect(viewModel.session.activeLabelId == regularLabel.id)
        #expect(viewModel.isIndependentTimerActive(linkedIndLabel.id) == true)
    }

    @Test("Unlinked independent timer does not affect regular timers")
    func unlinkedTimerDoesNotAffectRegular() {
        let indLabel = viewModel.independentLabels[0]
        #expect(indLabel.linkedLabelId == nil)

        viewModel.tap(viewModel.labels[0])
        let activeId = viewModel.session.activeLabelId

        viewModel.tapIndependentTimer(indLabel)
        #expect(viewModel.session.activeLabelId == activeId)
    }

    @Test("Multiple independent timers can run simultaneously")
    func multipleSimultaneousIndependentTimers() throws {
        try viewModel.addIndependentLabel(displayName: "Second Timer")
        let first = viewModel.independentLabels[0]
        let second = viewModel.independentLabels[1]

        viewModel.tapIndependentTimer(first)
        viewModel.tapIndependentTimer(second)

        #expect(viewModel.isIndependentTimerActive(first.id) == true)
        #expect(viewModel.isIndependentTimerActive(second.id) == true)
    }

    @Test("Independent timer time is excluded from totalFormattedHours")
    func independentTimerExcludedFromTotal() {
        viewModel.session.accumulated["project_1"] = 3600
        viewModel.session.independentAccumulated["independent_timer"] = 7200
        let result = viewModel.totalFormattedHours
        #expect(result == "1.00h")
    }

    @Test("independentFormattedHours shows accumulated time for a specific independent timer")
    func independentFormattedHoursDisplay() {
        viewModel.session.independentAccumulated["independent_timer"] = 3600
        let result = viewModel.independentFormattedHours(for: "independent_timer")
        #expect(result == "1.00h")
    }

    @Test("independentAccumulatedSeconds includes live elapsed for active independent timer")
    func independentAccumulatedSecondsActive() {
        let indLabel = viewModel.independentLabels[0]
        viewModel.tapIndependentTimer(indLabel)
        let result = viewModel.independentAccumulatedSeconds(for: indLabel.id)
        #expect(result >= -0.1)
        #expect(result < 1.0)
    }

    @Test("Independent timer runs independently of regular timers")
    func independentTimerIndependentOfRegular() {
        let label = TimerLabel.defaults[0]
        let indLabel = viewModel.independentLabels[0]
        viewModel.tap(label)
        viewModel.tapIndependentTimer(indLabel)
        #expect(viewModel.session.activeLabelId == label.id)
        #expect(viewModel.isIndependentTimerActive(indLabel.id) == true)
        viewModel.tap(label)
        #expect(viewModel.session.activeLabelId == nil)
        #expect(viewModel.isIndependentTimerActive(indLabel.id) == true)
    }

    // MARK: - Time Adjustment

    @Test("adjustTime increments accumulated time by 0.1 hours")
    func adjustTimeIncrement() {
        viewModel.session.accumulated["project_1"] = 3600
        viewModel.adjustTime(for: "project_1", byHours: 0.1)
        #expect(viewModel.session.accumulated["project_1"] == 3960)
    }

    @Test("adjustTime decrements accumulated time by 0.1 hours")
    func adjustTimeDecrement() {
        viewModel.session.accumulated["project_1"] = 3600
        viewModel.adjustTime(for: "project_1", byHours: -0.1)
        #expect(viewModel.session.accumulated["project_1"] == 3240)
    }

    @Test("adjustTime clamps to zero when decrementing below zero")
    func adjustTimeClampsToZero() {
        viewModel.session.accumulated["project_1"] = 100
        viewModel.adjustTime(for: "project_1", byHours: -0.1)
        #expect(viewModel.session.accumulated["project_1"] == 0)
    }

    @Test("adjustTime flushes active timer before adjusting")
    func adjustTimeFlushesActive() {
        let label = TimerLabel.defaults[0]
        viewModel.session.activeLabelId = label.id
        viewModel.session.activeStartedAt = Date()
        viewModel.session.accumulated[label.id] = 0

        viewModel.adjustTime(for: label.id, byHours: 0.1)

        #expect(viewModel.session.accumulated[label.id]! >= 360)
    }

    @Test("adjustIndependentTimerTime increments independent timer accumulated time")
    func adjustIndependentTimerTimeIncrement() {
        viewModel.session.independentAccumulated["independent_timer"] = 3600
        viewModel.adjustIndependentTimerTime(for: "independent_timer", byHours: 0.1)
        #expect(viewModel.session.independentAccumulated["independent_timer"] == 3960)
    }

    @Test("adjustIndependentTimerTime decrements independent timer accumulated time")
    func adjustIndependentTimerTimeDecrement() {
        viewModel.session.independentAccumulated["independent_timer"] = 3600
        viewModel.adjustIndependentTimerTime(for: "independent_timer", byHours: -0.1)
        #expect(viewModel.session.independentAccumulated["independent_timer"] == 3240)
    }

    @Test("adjustIndependentTimerTime clamps to zero when decrementing below zero")
    func adjustIndependentTimerTimeClampsToZero() {
        viewModel.session.independentAccumulated["independent_timer"] = 100
        viewModel.adjustIndependentTimerTime(for: "independent_timer", byHours: -0.1)
        #expect(viewModel.session.independentAccumulated["independent_timer"] == 0)
    }

    @Test("adjustTime is reflected in formattedHours")
    func adjustTimeReflectedInDisplay() {
        viewModel.session.accumulated["project_1"] = 0
        viewModel.adjustTime(for: "project_1", byHours: 0.1)
        #expect(viewModel.formattedHours(for: "project_1") == "0.10h")
    }

    @Test("adjustTime is reflected in totalFormattedHours")
    func adjustTimeReflectedInTotal() {
        viewModel.session.accumulated["project_1"] = 3600
        viewModel.adjustTime(for: "project_2", byHours: 0.1)
        #expect(viewModel.totalFormattedHours == "1.10h")
    }

    // MARK: - Reset

    @Test("resetTimers zeros all accumulated time and clears active label")
    func resetTimers() {
        viewModel.session.accumulated["project_1"] = 3600
        viewModel.tap(TimerLabel.defaults[0])
        viewModel.resetTimers()
        #expect(viewModel.session.activeLabelId == nil)
        for label in TimerLabel.defaults {
            #expect(viewModel.session.accumulated[label.id] == 0)
        }
    }

    // MARK: - Log Session

    @Test("logSession(to:) writes valid JSON to specified URL")
    func logSessionToURL() throws {
        viewModel.session.accumulated["project_1"] = 3600

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-log-\(UUID().uuidString).json")
        viewModel.logSession(to: tempFile)

        let data = try Data(contentsOf: tempFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let log = try decoder.decode(SessionLog.self, from: data)
        #expect(log.entries["project_1"]?.hours == 1.0)
        #expect(log.totalHours == 1.0)

        try? FileManager.default.removeItem(at: tempFile)
    }

    @Test("buildLog adjusts hours proportionally to an 8-hour day")
    func buildLogAdjustedHours() throws {
        viewModel.session.accumulated["project_1"] = 3600
        viewModel.session.accumulated["project_2"] = 3600

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-log-\(UUID().uuidString).json")
        viewModel.logSession(to: tempFile)

        let data = try Data(contentsOf: tempFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let log = try decoder.decode(SessionLog.self, from: data)

        #expect(log.entries["project_1"]?.adjustedHours == 4.0)
        #expect(log.entries["project_2"]?.adjustedHours == 4.0)
        #expect(log.entries["internal_training"]?.adjustedHours == 0.0)

        try? FileManager.default.removeItem(at: tempFile)
    }

    @Test("defaultLogFileName uses today's date")
    func defaultLogFileName() {
        let fileName = viewModel.defaultLogFileName
        #expect(fileName.hasSuffix(".json"))
        #expect(fileName.contains(TimerSession.todayString))
    }

    // MARK: - Label Management

    @Test("addLabel appends a new label")
    func addLabel() throws {
        let count = viewModel.labels.count
        try viewModel.addLabel(displayName: "My Custom")
        #expect(viewModel.labels.count == count + 1)
        #expect(viewModel.labels.last?.displayName == "My Custom")
    }

    @Test("addLabel initializes accumulated time to zero")
    func addLabelAccumulated() throws {
        try viewModel.addLabel(displayName: "New Label")
        let newId = viewModel.labels.last!.id
        #expect(viewModel.session.accumulated[newId] == 0)
    }

    @Test("addLabel throws error for duplicate label base name")
    func addLabelDuplicate() throws {
        try viewModel.addLabel(displayName: "Project Alpha")
        #expect(throws: LabelError.self) {
            try viewModel.addLabel(displayName: "Project Alpha")
        }
    }

    @Test("updateLabel renames an existing label")
    func updateLabel() {
        let label = viewModel.labels[0]
        viewModel.updateLabel(id: label.id, newDisplayName: "Renamed")
        #expect(viewModel.labels[0].displayName == "Renamed")
        #expect(viewModel.labels[0].id == label.id)
    }

    @Test("deleteLabel removes the label")
    func deleteLabel() {
        let count = viewModel.labels.count
        let label = viewModel.labels[0]
        viewModel.deleteLabel(id: label.id)
        #expect(viewModel.labels.count == count - 1)
        #expect(!viewModel.labels.contains(where: { $0.id == label.id }))
    }

    @Test("deleteLabel stops active timer if it was on the deleted label")
    func deleteLabelStopsActiveTimer() {
        let label = viewModel.labels[0]
        viewModel.tap(label)
        #expect(viewModel.session.activeLabelId == label.id)

        viewModel.deleteLabel(id: label.id)
        #expect(viewModel.session.activeLabelId == nil)
        #expect(viewModel.session.activeStartedAt == nil)
    }

    @Test("deleteLabel removes accumulated time for the deleted label")
    func deleteLabelRemovesAccumulated() {
        let label = viewModel.labels[0]
        viewModel.session.accumulated[label.id] = 3600
        viewModel.deleteLabel(id: label.id)
        #expect(viewModel.session.accumulated[label.id] == nil)
    }

    @Test("deleteLabel clears linked references in independent labels")
    func deleteLabelClearsLinkedReferences() throws {
        let regularLabel = viewModel.labels[0]
        try viewModel.addIndependentLabel(displayName: "Linked", linkedLabelId: regularLabel.id)
        let indLabel = viewModel.independentLabels.last!
        #expect(indLabel.linkedLabelId == regularLabel.id)

        viewModel.deleteLabel(id: regularLabel.id)

        let updated = viewModel.independentLabels.first(where: { $0.id == indLabel.id })!
        #expect(updated.linkedLabelId == nil)
    }

    @Test("labels default to TimerLabel.defaults on fresh init")
    func labelsDefaultToDefaults() {
        #expect(viewModel.labels.count == TimerLabel.defaults.count)
        for (a, b) in zip(viewModel.labels, TimerLabel.defaults) {
            #expect(a.id == b.id)
            #expect(a.displayName == b.displayName)
        }
    }

    // MARK: - Independent Label Management

    @Test("addIndependentLabel appends a new independent label")
    func addIndependentLabel() throws {
        let count = viewModel.independentLabels.count
        try viewModel.addIndependentLabel(displayName: "My Independent")
        #expect(viewModel.independentLabels.count == count + 1)
        #expect(viewModel.independentLabels.last?.displayName == "My Independent")
    }

    @Test("addIndependentLabel initializes accumulated time to zero")
    func addIndependentLabelAccumulated() throws {
        try viewModel.addIndependentLabel(displayName: "New Ind")
        let newId = viewModel.independentLabels.last!.id
        #expect(viewModel.session.independentAccumulated[newId] == 0)
    }

    @Test("updateIndependentLabel updates display name and linked label")
    func updateIndependentLabel() {
        let indLabel = viewModel.independentLabels[0]
        let regularLabel = viewModel.labels[0]
        viewModel.updateIndependentLabel(id: indLabel.id, newDisplayName: "Renamed", newLinkedLabelId: regularLabel.id)
        #expect(viewModel.independentLabels[0].displayName == "Renamed")
        #expect(viewModel.independentLabels[0].linkedLabelId == regularLabel.id)
    }

    @Test("deleteIndependentLabel removes the independent label")
    func deleteIndependentLabel() {
        let count = viewModel.independentLabels.count
        let indLabel = viewModel.independentLabels[0]
        viewModel.deleteIndependentLabel(id: indLabel.id)
        #expect(viewModel.independentLabels.count == count - 1)
        #expect(!viewModel.independentLabels.contains(where: { $0.id == indLabel.id }))
    }

    @Test("deleteIndependentLabel removes accumulated time and stops active timer")
    func deleteIndependentLabelCleansUp() {
        let indLabel = viewModel.independentLabels[0]
        viewModel.tapIndependentTimer(indLabel)
        viewModel.session.independentAccumulated[indLabel.id] = 3600

        viewModel.deleteIndependentLabel(id: indLabel.id)
        #expect(viewModel.session.independentAccumulated[indLabel.id] == nil)
        #expect(viewModel.session.activeIndependentTimers[indLabel.id] == nil)
    }
}
