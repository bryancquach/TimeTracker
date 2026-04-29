import SwiftUI

struct PopoverContentView: View {
    let viewModel: TimerViewModel
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(viewModel.labels) { label in
                LabelButtonView(
                    id: label.id,
                    displayName: label.displayName,
                    isActive: viewModel.session.activeLabelId == label.id,
                    elapsed: viewModel.formattedHours(for: label.id),
                    helpText: "Click to start/stop/switch timer for this project code",
                    action: { viewModel.tap(label) },
                    onIncrement: { viewModel.adjustTime(for: label.id, byHours: viewModel.timeIncrementHours) },
                    onDecrement: { viewModel.adjustTime(for: label.id, byHours: -viewModel.timeIncrementHours) }
                )
            }

            Divider()
                .padding(.vertical, 4)

            ForEach(viewModel.independentLabels) { indLabel in
                LabelButtonView(
                    id: indLabel.id,
                    displayName: indLabel.displayName,
                    isActive: viewModel.isIndependentTimerActive(indLabel.id),
                    elapsed: viewModel.independentFormattedHours(for: indLabel.id),
                    helpText: indLabel.linkedLabelId.flatMap { linkedId in
                        viewModel.labels.first(where: { $0.id == linkedId })?.displayName
                    }.map { "Linked to \($0)" },
                    action: { viewModel.tapIndependentTimer(indLabel) },
                    onIncrement: { viewModel.adjustIndependentTimerTime(for: indLabel.id, byHours: viewModel.timeIncrementHours) },
                    onDecrement: { viewModel.adjustIndependentTimerTime(for: indLabel.id, byHours: -viewModel.timeIncrementHours) }
                )
            }

            Divider()
                .padding(.vertical, 4)

            SessionActionsView(
                showLogConfirmation: viewModel.showLogConfirmation,
                defaultLogFileName: viewModel.defaultLogFileName,
                onLogDefault: { viewModel.logSession() },
                onLogToURL: { url in viewModel.logSession(to: url) },
                onReset: { viewModel.resetTimers() },
                onUpdate: { showRecalculatePanel() }
            )

            Divider()
                .padding(.vertical, 4)

            HStack {
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gear")
                        .foregroundStyle(showSettings ? .primary : .secondary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .hoverHighlight(default: showSettings ? 0.08 : 0)
                .help("Settings")

                Button(action: {
                    SingleWindowPresenter.show(
                        id: "logSummary",
                        title: "Time Tracking Summary",
                        size: NSSize(width: 700, height: 500),
                        minSize: NSSize(width: 500, height: 300)
                    ) {
                        LogSummaryView(viewModel: viewModel.makeLogSummaryViewModel())
                    }
                }) {
                    Image(systemName: "list.clipboard")
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .hoverHighlight()
                .help("View Log Summary")

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .help("Close the TimeTracker app")
                .hoverHighlight(color: .red, default: 0.15, hover: 0.25)
            }

            if showSettings {
                SettingsView(viewModel: viewModel)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSettings)
        .onDisappear { showSettings = false }
        .padding(12)
        .frame(width: 320)
        .alert("Recalculation Error", isPresented: showRecalculateErrorBinding) {
            Button("OK") {
                viewModel.recalculateError = nil
            }
        } message: {
            Text(viewModel.recalculateError ?? "")
        }
    }

    private var showRecalculateErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.recalculateError != nil },
            set: { if !$0 { viewModel.recalculateError = nil } }
        )
    }

    private func showRecalculatePanel() {
        FileDialogCoordinator.showOpenPanel(
            title: "Select Log File to Update",
            allowedContentTypes: [.json],
            directoryURL: viewModel.logsDirectoryURL,
            prompt: "Select"
        ) { url in
            Task { @MainActor in
                viewModel.recalculateLog(at: url)
            }
        }
    }
}
