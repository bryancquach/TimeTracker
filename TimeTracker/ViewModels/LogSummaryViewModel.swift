import Foundation

@MainActor
@Observable
final class LogSummaryViewModel {

    private(set) var days: [(day: String, result: DayLogResult)] = []
    private(set) var allLabelIds: [TimerLabel.ID] = []
    private(set) var allIndependentLabelIds: [IndependentTimerLabel.ID] = []

    var weekOffset: Int = 0 {
        didSet { loadDays() }
    }

    var canGoForward: Bool { weekOffset > 0 }

    private let persistence: SessionPersisting
    let labels: [TimerLabel]
    let independentLabels: [IndependentTimerLabel]

    init(persistence: SessionPersisting, labels: [TimerLabel],
         independentLabels: [IndependentTimerLabel]) {
        self.persistence = persistence
        self.labels = labels
        self.independentLabels = independentLabels
        loadDays()
    }

    func goBack() { weekOffset += 1 }

    func goForward() {
        guard canGoForward else { return }
        weekOffset -= 1
    }

    func displayName(for labelId: TimerLabel.ID) -> String {
        labels.first(where: { $0.id == labelId })?.displayName ?? labelId
    }

    func independentDisplayName(for labelId: IndependentTimerLabel.ID) -> String {
        independentLabels.first(where: { $0.id == labelId })?.displayName ?? labelId
    }

    private func loadDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let endDate = calendar.date(byAdding: .day, value: -(weekOffset * 7), to: today)!

        var results: [(String, DayLogResult)] = []
        var labelIdSet = Set<TimerLabel.ID>()
        var indLabelIdSet = Set<IndependentTimerLabel.ID>()

        for offset in (0..<7).reversed() {
            let date = calendar.date(byAdding: .day, value: -offset, to: endDate)!
            let dayString = TimerSession.dayString(for: date)
            do {
                if let log = try persistence.loadLog(for: dayString) {
                    results.append((dayString, .loaded(log)))
                    labelIdSet.formUnion(log.entries.keys)
                    indLabelIdSet.formUnion(log.independentTimerEntries.keys)
                } else {
                    results.append((dayString, .noData))
                }
            } catch {
                results.append((dayString, .error(error.localizedDescription)))
            }
        }

        days = results

        let knownOrder = labels.map(\.id)
        let known = knownOrder.filter { labelIdSet.contains($0) }
        let unknown = labelIdSet.subtracting(knownOrder).sorted()
        allLabelIds = known + unknown

        let knownIndOrder = independentLabels.map(\.id)
        let knownInd = knownIndOrder.filter { indLabelIdSet.contains($0) }
        let unknownInd = indLabelIdSet.subtracting(knownIndOrder).sorted()
        allIndependentLabelIds = knownInd + unknownInd
    }
}
