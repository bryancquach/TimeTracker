import SwiftUI
import os

@MainActor
@Observable
final class TimerViewModel {

    private static let log = Logger(subsystem: "com.timetracker", category: "TimerViewModel")

    // MARK: - Observed State

    var session: TimerSession
    var showLogConfirmation = false
    var recalculateError: String?

    let labelManager: LabelManager

    var labels: [TimerLabel] { labelManager.labels }
    var independentLabels: [IndependentTimerLabel] { labelManager.independentLabels }

    /// User-configurable log output directory path, or nil for the default.
    var customLogDirectoryPath: String? = UserDefaults.standard.string(forKey: AppConstants.logDirectoryKey)

    /// User-configurable increment/decrement amount (minutes) for the +/− buttons.
    var timeIncrementMinutes: Int = TimerViewModel.storedTimeIncrementMinutes() {
        didSet {
            let clamped = Self.clampIncrement(timeIncrementMinutes)
            if timeIncrementMinutes != clamped { timeIncrementMinutes = clamped }
            UserDefaults.standard.set(timeIncrementMinutes, forKey: AppConstants.timeIncrementMinutesKey)
        }
    }

    /// The increment amount in hours, as used by `adjustTime(for:byHours:)`.
    var timeIncrementHours: Double { Double(timeIncrementMinutes) / 60 }

    /// Whether all timers are automatically stopped each day at `autoStopMinutes`.
    var autoStopEnabled: Bool = UserDefaults.standard.bool(forKey: AppConstants.autoStopEnabledKey) {
        didSet { UserDefaults.standard.set(autoStopEnabled, forKey: AppConstants.autoStopEnabledKey) }
    }

    /// Daily auto-stop time, in minutes after local midnight.
    var autoStopMinutes: Int = TimerViewModel.storedAutoStopMinutes() {
        didSet {
            let clamped = AutoStopSchedule.clamp(autoStopMinutes)
            if autoStopMinutes != clamped { autoStopMinutes = clamped }
            UserDefaults.standard.set(autoStopMinutes, forKey: AppConstants.autoStopMinutesKey)
        }
    }

    /// Auto-stop time as a `Date` (today), for binding to a time picker.
    var autoStopTime: Date {
        get { autoStopSchedule.cutoff(onDayOf: Date()) ?? Date() }
        set {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            autoStopMinutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
    }

    /// Localized short time string for the auto-stop time, e.g. "5:00 PM".
    var autoStopTimeText: String {
        autoStopTime.formatted(date: .omitted, time: .shortened)
    }

    /// Updated every second to drive live elapsed-time display.
    private(set) var currentDate = Date()

    // MARK: - Private

    private let persistence: SessionPersisting
    private let logger: SessionLogger
    private let dayRolloverService = DayRolloverService()
    private let scheduler = TickScheduler()
    private var sleepWakeService: SleepWakeService?
    private var wasActiveBeforeSleep: TimerLabel.ID?
    private var wasIndependentTimersActiveBeforeSleep: [IndependentTimerLabel.ID: Date] = [:]
    /// Last moment the auto-stop cutoff was checked; a cutoff falling after this is "crossed".
    /// Checked on each persist cycle (every minute), on wake, and before any timer mutation.
    private var lastAutoStopCheck = Date()

    private var autoStopSchedule: AutoStopSchedule {
        AutoStopSchedule(minutesAfterMidnight: autoStopMinutes)
    }

    // MARK: - Init

    init(persistence: SessionPersisting = PersistenceService()) {
        self.persistence = persistence
        self.logger = SessionLogger(persistence: persistence)
        try? persistence.ensureDirectories()

        let loadedLabels = (try? persistence.loadLabels()) ?? TimerLabel.defaults
        let loadedIndependentLabels = (try? persistence.loadIndependentLabels()) ?? IndependentTimerLabel.defaults
        self.labelManager = LabelManager(
            labels: loadedLabels,
            independentLabels: loadedIndependentLabels,
            persistence: persistence
        )

        let today = TimerSession.todayString

        if var loaded = try? persistence.loadSession() {
            // If the cutoff passed while the app wasn't running, stop timers at the cutoff.
            if UserDefaults.standard.bool(forKey: AppConstants.autoStopEnabledKey),
               let lastStart = loaded.earliestActiveStart {
                let schedule = AutoStopSchedule(minutesAfterMidnight: Self.storedAutoStopMinutes())
                if let cutoff = schedule.firstCutoff(after: lastStart, through: Date()) {
                    loaded.stopTimers(at: cutoff)
                }
            }
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
        TimeFormatting.formattedHours(from: accumulatedSeconds(for: labelId))
    }

    var totalFormattedHours: String {
        let total = labels.reduce(0.0) { $0 + accumulatedSeconds(for: $1.id) }
        return TimeFormatting.formattedHours(from: total)
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
        TimeFormatting.formattedHours(from: independentAccumulatedSeconds(for: labelId))
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
        let label = try labelManager.addIndependentLabel(displayName: displayName, linkedLabelId: linkedLabelId)
        session.independentAccumulated[label.id] = 0
        persist()
    }

    func updateIndependentLabel(id: String, newDisplayName: String, newLinkedLabelId: TimerLabel.ID?) {
        labelManager.updateIndependentLabel(id: id, newDisplayName: newDisplayName, newLinkedLabelId: newLinkedLabelId)
    }

    func deleteIndependentLabel(id: String) {
        labelManager.deleteIndependentLabel(id: id)
        session.activeIndependentTimers.removeValue(forKey: id)
        session.independentAccumulated.removeValue(forKey: id)
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

    func exportDataToFile(at url: URL) throws {
        guard let bundle = exportData() else { return }
        let data = try JSONCoding.encoder.encode(bundle)
        try data.write(to: url, options: .atomic)
    }

    func importData(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let bundle = try JSONCoding.decoder.decode(AppDataBundle.self, from: data)
        labelManager.replaceAll(labels: bundle.labels, independentLabels: bundle.independentLabels)
        if let imported = bundle.session {
            session = imported
        } else {
            session = .fresh(day: TimerSession.todayString, labels: labels, independentLabels: independentLabels)
        }
        persist()
        for log in bundle.logs {
            try? persistence.saveLog(log)
        }
    }

    func clearAllData() throws {
        try persistence.clearAllData()
        labelManager.resetToDefaults()
        session = .fresh(day: TimerSession.todayString, labels: labels, independentLabels: independentLabels)
        persist()
    }

    // MARK: - Label Management

    func addLabel(displayName: String) throws {
        let label = try labelManager.addLabel(displayName: displayName)
        session.accumulated[label.id] = 0
        persist()
    }

    func updateLabel(id: String, newDisplayName: String) {
        labelManager.updateLabel(id: id, newDisplayName: newDisplayName)
    }

    func moveLabel(from source: IndexSet, to destination: Int) {
        labelManager.moveLabel(from: source, to: destination)
    }

    func deleteLabel(id: String) {
        labelManager.deleteLabel(id: id) { [self] in
            if session.activeLabelId == id {
                flush()
                session.activeLabelId = nil
                session.activeStartedAt = nil
            }
            session.accumulated.removeValue(forKey: id)
        }
        persist()
    }

    // MARK: - Auto-Stop

    /// Stops all timers if the daily cutoff has been crossed since the last check.
    /// Also discards timers paused for sleep so they are not resumed on wake.
    func checkAutoStop(now: Date = Date()) {
        defer { lastAutoStopCheck = now }
        guard autoStopEnabled,
              let cutoff = autoStopSchedule.firstCutoff(after: lastAutoStopCheck, through: now)
        else { return }

        session.stopTimers(at: cutoff)
        wasActiveBeforeSleep = nil
        wasIndependentTimersActiveBeforeSleep = [:]
        persist()
    }

    // MARK: - Time Increment Setting

    static func clampIncrement(_ minutes: Int) -> Int {
        let range = AppConstants.timeIncrementMinutesRange
        return min(range.upperBound, max(range.lowerBound, minutes))
    }

    /// Loads the saved increment in minutes, migrating a legacy hours value if present.
    static func storedTimeIncrementMinutes(defaults: UserDefaults = .standard) -> Int {
        if let minutes = defaults.object(forKey: AppConstants.timeIncrementMinutesKey) as? Int {
            return clampIncrement(minutes)
        }
        if let hours = defaults.object(forKey: AppConstants.legacyTimeIncrementHoursKey) as? Double, hours > 0 {
            let migrated = clampIncrement(Int((hours * 60).rounded()))
            defaults.set(migrated, forKey: AppConstants.timeIncrementMinutesKey)
            defaults.removeObject(forKey: AppConstants.legacyTimeIncrementHoursKey)
            return migrated
        }
        return AppConstants.defaultTimeIncrementMinutes
    }

    private static func storedAutoStopMinutes() -> Int {
        let stored = UserDefaults.standard.object(forKey: AppConstants.autoStopMinutesKey) as? Int
        return AutoStopSchedule.clamp(stored ?? AppConstants.defaultAutoStopMinutes)
    }

    // MARK: - Log Summary

    func makeLogSummaryViewModel() -> LogSummaryViewModel {
        LogSummaryViewModel(persistence: persistence, labels: labels, independentLabels: independentLabels)
    }

    // MARK: - Private Helpers

    private func flush() {
        // Apply a pending auto-stop first so a flush between the minute checks
        // can't move timer start times past the cutoff and dodge it.
        checkAutoStop()
        session.flush()
    }

    private func setupScheduler() {
        scheduler.onTick = { [weak self] in
            self?.currentDate = Date()
        }
        scheduler.onPersistCycle = { [weak self] in
            self?.checkAutoStop()
            self?.checkDayRollover()
            self?.flush()
            self?.persist()
        }
        scheduler.start()
    }

    private func checkDayRollover() {
        let today = TimerSession.todayString
        guard let result = dayRolloverService.rolloverIfNeeded(
            session: session,
            today: today,
            labels: labels,
            independentLabels: independentLabels
        ) else { return }

        if let stale = result.staleSessionToLog {
            logger.log(stale, labels: labels, independentLabels: independentLabels)
        }
        session = result.newSession
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
        // Drops the paused-for-sleep timers if the cutoff passed while asleep.
        checkAutoStop()
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
