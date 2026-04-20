import Testing
import Foundation
@testable import TimeTracker

@Suite("LogSummaryViewModel", .serialized)
@MainActor
struct LogSummaryViewModelTests {

    private static func makeTempService() throws -> PersistenceService {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeTrackerTests-\(UUID().uuidString)")
        let service = PersistenceService(baseURL: dir)
        try service.ensureDirectories()
        return service
    }

    private static let testLabels: [TimerLabel] = [
        .init(id: "label_a", displayName: "Label A"),
        .init(id: "label_b", displayName: "Label B"),
    ]

    private static let testIndependentLabels: [IndependentTimerLabel] = [
        .init(id: "ind_a", displayName: "Ind A", linkedLabelId: nil),
    ]

    // MARK: - Initial State

    @Test("Initial load populates 7 days ending today")
    func initialLoadPopulatesDays() throws {
        let service = try Self.makeTempService()
        let vm = LogSummaryViewModel(
            persistence: service,
            labels: Self.testLabels,
            independentLabels: Self.testIndependentLabels
        )
        #expect(vm.days.count == 7)
        let today = TimerSession.todayString
        #expect(vm.days.last?.day == today)
    }

    @Test("Days without log files show noData")
    func emptyDirectoryShowsNoData() throws {
        let service = try Self.makeTempService()
        let vm = LogSummaryViewModel(
            persistence: service,
            labels: Self.testLabels,
            independentLabels: Self.testIndependentLabels
        )
        for entry in vm.days {
            if case .noData = entry.result {
                // expected
            } else {
                Issue.record("Expected .noData for \(entry.day), got \(entry.result)")
            }
        }
    }

    // MARK: - Loading Logs

    @Test("Days with valid logs show loaded")
    func validLogShowsLoaded() throws {
        let service = try Self.makeTempService()
        let today = TimerSession.todayString
        let log = SessionLog(
            day: today,
            totalHours: 2.0,
            entries: [
                "label_a": SessionLogEntry(hours: 1.0, adjustedHours: 4.0),
                "label_b": SessionLogEntry(hours: 1.0, adjustedHours: 4.0),
            ],
            loggedAt: Date()
        )
        try service.saveLog(log)

        let vm = LogSummaryViewModel(
            persistence: service,
            labels: Self.testLabels,
            independentLabels: Self.testIndependentLabels
        )
        let todayEntry = vm.days.first(where: { $0.day == today })
        guard case .loaded(let loaded) = todayEntry?.result else {
            Issue.record("Expected .loaded for today")
            return
        }
        #expect(loaded.totalHours == 2.0)
        #expect(loaded.entries["label_a"]?.hours == 1.0)
    }

    @Test("Days with corrupt files show error")
    func corruptFileShowsError() throws {
        let service = try Self.makeTempService()
        let today = TimerSession.todayString
        let url = service.logsDirectoryURL.appendingPathComponent("\(today).json")
        try "not valid json {{{".data(using: .utf8)!.write(to: url, options: .atomic)

        let vm = LogSummaryViewModel(
            persistence: service,
            labels: Self.testLabels,
            independentLabels: Self.testIndependentLabels
        )
        let todayEntry = vm.days.first(where: { $0.day == today })
        if case .error = todayEntry?.result {
            // expected
        } else {
            Issue.record("Expected .error for corrupt file, got \(String(describing: todayEntry?.result))")
        }
    }

    // MARK: - Navigation

    @Test("canGoForward is false at weekOffset 0")
    func canGoForwardFalseAtZero() throws {
        let service = try Self.makeTempService()
        let vm = LogSummaryViewModel(
            persistence: service,
            labels: Self.testLabels,
            independentLabels: Self.testIndependentLabels
        )
        #expect(vm.canGoForward == false)
    }

    @Test("goBack shifts window 7 days earlier")
    func goBackShiftsWindow() throws {
        let service = try Self.makeTempService()
        let vm = LogSummaryViewModel(
            persistence: service,
            labels: Self.testLabels,
            independentLabels: Self.testIndependentLabels
        )
        let lastDayBefore = vm.days.last!.day
        vm.goBack()
        #expect(vm.weekOffset == 1)
        #expect(vm.canGoForward == true)
        let lastDayAfter = vm.days.last!.day
        #expect(lastDayAfter != lastDayBefore)

        let daysBetween = TimerSession.daysBetween(lastDayAfter, lastDayBefore)
        #expect(daysBetween == 7)
    }

    @Test("goForward moves window forward and is blocked at 0")
    func goForwardBlockedAtZero() throws {
        let service = try Self.makeTempService()
        let vm = LogSummaryViewModel(
            persistence: service,
            labels: Self.testLabels,
            independentLabels: Self.testIndependentLabels
        )
        vm.goBack()
        vm.goBack()
        #expect(vm.weekOffset == 2)
        vm.goForward()
        #expect(vm.weekOffset == 1)
        vm.goForward()
        #expect(vm.weekOffset == 0)
        vm.goForward()
        #expect(vm.weekOffset == 0)
    }

    // MARK: - Label Resolution

    @Test("displayName resolves known labels and falls back to raw ID")
    func displayNameResolution() throws {
        let service = try Self.makeTempService()
        let vm = LogSummaryViewModel(
            persistence: service,
            labels: Self.testLabels,
            independentLabels: Self.testIndependentLabels
        )
        #expect(vm.displayName(for: "label_a") == "Label A")
        #expect(vm.displayName(for: "unknown_id") == "unknown_id")
    }

    @Test("independentDisplayName resolves known labels and falls back to raw ID")
    func independentDisplayNameResolution() throws {
        let service = try Self.makeTempService()
        let vm = LogSummaryViewModel(
            persistence: service,
            labels: Self.testLabels,
            independentLabels: Self.testIndependentLabels
        )
        #expect(vm.independentDisplayName(for: "ind_a") == "Ind A")
        #expect(vm.independentDisplayName(for: "unknown_ind") == "unknown_ind")
    }

    // MARK: - Label ID Ordering

    @Test("allLabelIds preserves known label order then appends unknown IDs")
    func allLabelIdsOrdering() throws {
        let service = try Self.makeTempService()
        let today = TimerSession.todayString
        let log = SessionLog(
            day: today,
            totalHours: 3.0,
            entries: [
                "label_b": SessionLogEntry(hours: 1.0, adjustedHours: 2.67),
                "label_a": SessionLogEntry(hours: 1.0, adjustedHours: 2.67),
                "deleted_label": SessionLogEntry(hours: 1.0, adjustedHours: 2.67),
            ],
            loggedAt: Date()
        )
        try service.saveLog(log)

        let vm = LogSummaryViewModel(
            persistence: service,
            labels: Self.testLabels,
            independentLabels: Self.testIndependentLabels
        )

        #expect(vm.allLabelIds.count == 3)
        #expect(vm.allLabelIds[0] == "label_a")
        #expect(vm.allLabelIds[1] == "label_b")
        #expect(vm.allLabelIds[2] == "deleted_label")
    }
}
