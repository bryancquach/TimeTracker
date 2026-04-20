import SwiftUI
import os

@MainActor
@Observable
final class TimerViewModel {

    private static let log = Logger(subsystem: "com.timetracker", category: "TimerViewModel")

    // MARK: - Observed State

    var session: TimerSession
    var labels: [TimerLabel]
    var independentLabels: [IndependentTimerLabel]
    var showLogConfirmation = false
    var recalculateError: String?

    /// User-configurable log output directory path, or nil for the default.
    var customLogDirectoryPath: String? = UserDefaults.standard.string(forKey: AppConstants.logDirectoryKey)

    /// User-configurable increment/decrement amount (hours) for the +/− buttons.
    var timeIncrementHours: Double = AppConstants.defaultTimeIncrementHours {
        didSet {
            let clamped = min(1.0, max(0.05, timeIncrementHours))
            if timeIncrementHours != clamped { timeIncrementHours = clamped }
            UserDefaults.standard.set(timeIncrementHours, forKey: AppConstants.timeIncrementKey)
        }
    }

    /// Updated every second to drive live elapsed-time display.
    private(set) var currentDate = Date()

    // MARK: - Private

    private let persistence: SessionPersisting
    private let logger: SessionLogger
    private let scheduler = TickScheduler()
    private var sleepWakeService: SleepWakeService?
    private var wasActiveBeforeSleep: TimerLabel.ID?
    private var wasIndependentTimersActiveBeforeSleep: [IndependentTimerLabel.ID: Date] = [:]

    // MARK: - Init

    init(persistence: SessionPersisting = PersistenceService()) {
        self.persistence = persistence
        self.logger = SessionLogger(persistence: persistence)
        try? persistence.ensureDirectories()

        let loadedLabels = (try? persistence.loadLabels()) ?? TimerLabel.defaults
        self.labels = loadedLabels

        let loadedIndependentLabels = (try? persistence.loadIndependentLabels()) ?? IndependentTimerLabel.defaults
        self.independentLabels = loadedIndependentLabels

        let today = TimerSession.todayString

        if var loaded = try? persistence.loadSession() {
            if loaded.day != today {
                if let endOfDay = TimerSession.endOfDay(for: loaded.day) {
                    loaded.flush(at: endOfDay)
                } else {
                    loaded.flush()
                }
                let withinLimit = TimerSession.daysBetween(loaded.day, today)
                    .map { $0 <= AppConstants.maxRetroactiveDays } ?? false
                if withinLimit {
                    logger.log(loaded, labels: loadedLabels, independentLabels: loadedIndependentLabels)
                }
                session = .fresh(day: today, labels: loadedLabels, independentLabels: loadedIndependentLabels)
            } else {
                loaded.flush()
                session = loaded
            }
        } else {
            session = .fresh(day: today, labels: loadedLabels, independentLabels: loadedIndependentLabels)
        }

        let saved = UserDefaults.standard.double(forKey: AppConstants.timeIncrementKey)
        if saved >= 0.05 && saved <= 1.0 {
            timeIncrementHours = saved
        }

        persist()
        setupScheduler()
        setupSleepWake()
        setupTerminationHandler()
    }

    // MARK: - Button Tap

    func tap(_ label: TimerLabel) {
        flush()
        if session.activeLabelId == label.id {
            session.activeLabelId = nil
            session.activeStartedAt = nil
        } else {
            session.activeLabelId = label.id
            session.activeStartedAt = Date()
        }
        persist()
    }

    // MARK: - Display Helpers

    func accumulatedSeconds(for labelId: TimerLabel.ID) -> TimeInterval {
        var total = session.accumulated[labelId, default: 0]
        if session.activeLabelId == labelId, let startedAt = session.activeStartedAt {
            total += currentDate.timeIntervalSince(startedAt)
        }
        return total
    }

    func formattedHours(for labelId: TimerLabel.ID) -> String {
        String(format: "%.2fh", accumulatedSeconds(for: labelId).asHours)
    }

    var totalFormattedHours: String {
        let total = labels.reduce(0.0) { $0 + accumulatedSeconds(for: $1.id) }
        return String(format: "%.2fh", total.asHours)
    }

    // MARK: - Time Adjustment

    func adjustTime(for labelId: TimerLabel.ID, byHours delta: Double) {
        flush()
        let current = session.accumulated[labelId, default: 0]
        session.accumulated[labelId] = max(0, current + delta * 3600)
        persist()
    }

    // MARK: - Independent Timers

    func tapIndependentTimer(_ label: IndependentTimerLabel) {
        flush()
        if session.activeIndependentTimers[label.id] != nil {
            session.activeIndependentTimers.removeValue(forKey: label.id)
        } else {
            session.activeIndependentTimers[label.id] = Date()
            if let linkedId = label.linkedLabelId,
               labels.contains(where: { $0.id == linkedId }) {
                session.activeLabelId = linkedId
                session.activeStartedAt = Date()
            }
        }
        persist()
    }

    func independentAccumulatedSeconds(for labelId: IndependentTimerLabel.ID) -> TimeInterval {
        var total = session.independentAccumulated[labelId, default: 0]
        if let startedAt = session.activeIndependentTimers[labelId] {
            total += currentDate.timeIntervalSince(startedAt)
        }
        return total
    }

    func independentFormattedHours(for labelId: IndependentTimerLabel.ID) -> String {
        String(format: "%.2fh", independentAccumulatedSeconds(for: labelId).asHours)
    }

    func adjustIndependentTimerTime(for labelId: IndependentTimerLabel.ID, byHours delta: Double) {
        flush()
        let current = session.independentAccumulated[labelId, default: 0]
        session.independentAccumulated[labelId] = max(0, current + delta * 3600)
        persist()
    }

    func isIndependentTimerActive(_ labelId: IndependentTimerLabel.ID) -> Bool {
        session.activeIndependentTimers[labelId] != nil
    }

    // MARK: - Independent Label Management

    func addIndependentLabel(displayName: String, linkedLabelId: TimerLabel.ID? = nil) throws {
        let existingIds = independentLabels.map { $0.id }
        let id = try IndependentTimerLabel.generateId(from: displayName, existingIds: existingIds)
        let label = IndependentTimerLabel(id: id, displayName: displayName, linkedLabelId: linkedLabelId)
        independentLabels.append(label)
        session.independentAccumulated[id] = 0
        saveIndependentLabels()
        persist()
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
        session.activeIndependentTimers.removeValue(forKey: id)
        session.independentAccumulated.removeValue(forKey: id)
        saveIndependentLabels()
        persist()
    }

    // MARK: - Log Session

    func logSession() {
        flush()
        logger.log(session, labels: labels, independentLabels: independentLabels)
        flashConfirmation()
    }

    func logSession(to url: URL) {
        flush()
        logger.log(session, labels: labels, independentLabels: independentLabels, to: url)
        flashConfirmation()
    }

    var defaultLogFileName: String {
        "\(TimerSession.todayString).json"
    }

    var logsDirectoryURL: URL { persistence.logsDirectoryURL }

    func setCustomLogDirectory(_ url: URL) {
        let path = url.path
        UserDefaults.standard.set(path, forKey: AppConstants.logDirectoryKey)
        customLogDirectoryPath = path
        try? persistence.ensureDirectories()
    }

    func clearCustomLogDirectory() {
        UserDefaults.standard.removeObject(forKey: AppConstants.logDirectoryKey)
        customLogDirectoryPath = nil
    }

    func recalculateLog(at url: URL) {
        do {
            try logger.recalculateLogFile(at: url)
        } catch {
            recalculateError = error.localizedDescription
        }
    }

    private func flashConfirmation() {
        showLogConfirmation = true
        Task {
            try? await Task.sleep(for: .seconds(AppConstants.confirmationDisplaySeconds))
            showLogConfirmation = false
        }
    }

    // MARK: - Reset

    func resetTimers() {
        session = .fresh(day: TimerSession.todayString, labels: labels, independentLabels: independentLabels)
        persist()
    }

    // MARK: - App Data Management

    func exportData() -> AppDataBundle? {
        flush()
        let logs = (try? persistence.loadAllLogs()) ?? []
        return AppDataBundle(
            labels: labels,
            independentLabels: independentLabels,
            session: session,
            logs: logs
        )
    }

    func importData(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let bundle = try PersistenceService.decoder.decode(AppDataBundle.self, from: data)
        labels = bundle.labels
        independentLabels = bundle.independentLabels
        if let imported = bundle.session {
            session = imported
        } else {
            session = .fresh(day: TimerSession.todayString, labels: labels, independentLabels: independentLabels)
        }
        saveLabels()
        saveIndependentLabels()
        persist()
        for log in bundle.logs {
            try? persistence.saveLog(log)
        }
    }

    func clearAllData() throws {
        try persistence.clearAllData()
        labels = TimerLabel.defaults
        independentLabels = IndependentTimerLabel.defaults
        session = .fresh(day: TimerSession.todayString, labels: labels, independentLabels: independentLabels)
        saveLabels()
        saveIndependentLabels()
        persist()
    }

    // MARK: - Label Management

    func addLabel(displayName: String) throws {
        let existingIds = labels.map { $0.id }
        let id = try TimerLabel.generateId(from: displayName, existingIds: existingIds)
        let label = TimerLabel(id: id, displayName: displayName)
        labels.append(label)
        session.accumulated[id] = 0
        saveLabels()
        persist()
    }

    func updateLabel(id: String, newDisplayName: String) {
        guard let index = labels.firstIndex(where: { $0.id == id }) else { return }
        labels[index].displayName = newDisplayName
        saveLabels()
    }

    func moveLabel(from source: IndexSet, to destination: Int) {
        labels.move(fromOffsets: source, toOffset: destination)
        saveLabels()
    }

    func deleteLabel(id: String) {
        guard let index = labels.firstIndex(where: { $0.id == id }) else { return }
        labels.remove(at: index)
        if session.activeLabelId == id {
            flush()
            session.activeLabelId = nil
            session.activeStartedAt = nil
        }
        session.accumulated.removeValue(forKey: id)

        for i in independentLabels.indices where independentLabels[i].linkedLabelId == id {
            independentLabels[i].linkedLabelId = nil
        }
        saveIndependentLabels()

        saveLabels()
        persist()
    }

    // MARK: - Private Helpers

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

    private func flush() {
        session.flush()
    }

    private func setupScheduler() {
        scheduler.onTick = { [weak self] in
            self?.currentDate = Date()
        }
        scheduler.onPersistCycle = { [weak self] in
            self?.checkDayRollover()
            self?.flush()
            self?.persist()
        }
        scheduler.start()
    }

    private func checkDayRollover() {
        let today = TimerSession.todayString
        guard session.day != today else { return }

        let wasActive = session.activeLabelId
        let wasIndependentTimersActive = session.activeIndependentTimers

        if let endOfDay = TimerSession.endOfDay(for: session.day) {
            session.flush(at: endOfDay)
        } else {
            session.flush()
        }

        session.activeLabelId = nil
        session.activeStartedAt = nil
        session.activeIndependentTimers = [:]

        let withinLimit = TimerSession.daysBetween(session.day, today)
            .map { $0 <= AppConstants.maxRetroactiveDays } ?? false
        if withinLimit {
            logger.log(session, labels: labels, independentLabels: independentLabels)
        }

        session = .fresh(day: today, labels: labels, independentLabels: independentLabels)

        let midnight = TimerSession.startOfDay(for: today) ?? Date()
        if let activeId = wasActive {
            session.activeLabelId = activeId
            session.activeStartedAt = midnight
        }
        for (id, _) in wasIndependentTimersActive {
            session.activeIndependentTimers[id] = midnight
        }
    }

    private func persist() {
        do {
            try persistence.saveSession(session)
        } catch {
            Self.log.error("Failed to persist session: \(error.localizedDescription)")
        }
    }

    // MARK: - Sleep / Wake

    private func setupSleepWake() {
        sleepWakeService = SleepWakeService(
            onSleep: { [weak self] in
                Task { @MainActor in self?.handleSleep() }
            },
            onWake: { [weak self] in
                Task { @MainActor in self?.handleWake() }
            }
        )
    }

    private func handleSleep() {
        flush()
        wasActiveBeforeSleep = session.activeLabelId
        wasIndependentTimersActiveBeforeSleep = session.activeIndependentTimers
        session.activeLabelId = nil
        session.activeStartedAt = nil
        session.activeIndependentTimers = [:]
        persist()
    }

    private func handleWake() {
        checkDayRollover()
        var needsPersist = false
        if let labelId = wasActiveBeforeSleep {
            session.activeLabelId = labelId
            session.activeStartedAt = Date()
            wasActiveBeforeSleep = nil
            needsPersist = true
        }
        if !wasIndependentTimersActiveBeforeSleep.isEmpty {
            let now = Date()
            for (id, _) in wasIndependentTimersActiveBeforeSleep {
                session.activeIndependentTimers[id] = now
            }
            wasIndependentTimersActiveBeforeSleep = [:]
            needsPersist = true
        }
        if needsPersist {
            persist()
        }
    }

    // MARK: - Termination

    private func setupTerminationHandler() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.flush()
                self?.persist()
            }
        }
    }
}
