import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    let viewModel: TimerViewModel
    @State private var showClearConfirmation = false
    @State private var dataError: String?

    var body: some View {
        VStack(spacing: 6) {

            Spacer()
                .frame(height: 10)

            HStack {
                Text("Manual Time Increment Amount")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: {
                    viewModel.timeIncrementHours = max(0.05, viewModel.timeIncrementHours - 0.05)
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .hoverHighlight(hover: 0.08, horizontalPadding: 2, verticalPadding: 2, cornerRadius: 4)

                Text(String(format: "%.2fh", viewModel.timeIncrementHours))
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Button(action: {
                    viewModel.timeIncrementHours = min(1.0, viewModel.timeIncrementHours + 0.05)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .hoverHighlight(hover: 0.08, horizontalPadding: 2, verticalPadding: 2, cornerRadius: 4)
            }

            HStack {
                Text("Log directory")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()

                if viewModel.customLogDirectoryPath != nil {
                    Button("Reset") {
                        viewModel.clearCustomLogDirectory()
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .hoverHighlight(hover: 0.08, horizontalPadding: 6, verticalPadding: 2, cornerRadius: 4)
                }

                Button("Choose\u{2026}") {
                    showDirectoryPicker()
                }
                .font(.callout.bold())
                .hoverHighlight(hover: 0.08, horizontalPadding: 6, verticalPadding: 2, cornerRadius: 4)
            }

            if let path = viewModel.customLogDirectoryPath {
                Text(path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack {
                Button("Manage Labels\u{2026}") {
                    SingleWindowPresenter.show(
                        id: "labelManager",
                        title: "Timer Labels",
                        size: NSSize(width: 300, height: 400),
                        minSize: NSSize(width: 250, height: 200)
                    ) {
                        LabelManagerView(
                            viewModel: viewModel,
                            onDone: { SingleWindowPresenter.close(id: "labelManager") }
                        )
                    }
                }
                .font(.callout.bold())
                .hoverHighlight(hover: 0.08, horizontalPadding: 6, verticalPadding: 2, cornerRadius: 4)

                Spacer()
            }

            HStack {
                Button("Manage Independent Timers\u{2026}") {
                    SingleWindowPresenter.show(
                        id: "independentLabelManager",
                        title: "Independent Timers",
                        size: NSSize(width: 350, height: 400),
                        minSize: NSSize(width: 300, height: 200)
                    ) {
                        IndependentLabelManagerView(
                            viewModel: viewModel,
                            onDone: { SingleWindowPresenter.close(id: "independentLabelManager") }
                        )
                    }
                }
                .font(.callout.bold())
                .hoverHighlight(hover: 0.08, horizontalPadding: 6, verticalPadding: 2, cornerRadius: 4)

                Spacer()
            }

            Divider()
                .padding(.vertical, 4)

            HStack {
                Text("App Data")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 8) {
                if showClearConfirmation {
                    Text("Clear all data?")
                        .font(.callout)
                        .foregroundStyle(.red)

                    Button("Confirm") {
                        do {
                            try viewModel.clearAllData()
                        } catch {
                            dataError = error.localizedDescription
                        }
                        showClearConfirmation = false
                    }
                    .buttonStyle(.plain)
                    .font(.callout.bold())
                    .foregroundStyle(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)

                    Button("Cancel") {
                        showClearConfirmation = false
                    }
                    .buttonStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                } else {
                    Button("Clear") {
                        showClearConfirmation = true
                    }
                    .font(.callout.bold())
                    .hoverHighlight(hover: 0.08, horizontalPadding: 6, verticalPadding: 2, cornerRadius: 4)

                    Button("Export\u{2026}") {
                        exportData()
                    }
                    .font(.callout.bold())
                    .hoverHighlight(hover: 0.08, horizontalPadding: 6, verticalPadding: 2, cornerRadius: 4)

                    Button("Import\u{2026}") {
                        importData()
                    }
                    .font(.callout.bold())
                    .hoverHighlight(hover: 0.08, horizontalPadding: 6, verticalPadding: 2, cornerRadius: 4)
                }

                Spacer()
            }

            if let error = dataError {
                HStack {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Spacer()
                    Button("Dismiss") { dataError = nil }
                        .font(.caption2)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func exportData() {
        FileDialogCoordinator.showSavePanel(
            title: "Export App Data",
            fileName: "TimeTracker-export.json"
        ) { url in
            Task { @MainActor in
                do {
                    try viewModel.exportDataToFile(at: url)
                } catch {
                    dataError = error.localizedDescription
                }
            }
        }
    }

    private func importData() {
        FileDialogCoordinator.showOpenPanel(
            title: "Import App Data",
            allowedContentTypes: [.json]
        ) { url in
            Task { @MainActor in
                do {
                    try viewModel.importData(from: url)
                } catch {
                    dataError = error.localizedDescription
                }
            }
        }
    }

    private func showDirectoryPicker() {
        let directoryURL: URL
        if let current = viewModel.customLogDirectoryPath {
            directoryURL = URL(fileURLWithPath: current, isDirectory: true)
        } else {
            directoryURL = viewModel.logsDirectoryURL
        }
        FileDialogCoordinator.showOpenPanel(
            title: "Select Log Output Directory",
            canChooseFiles: false,
            canChooseDirectories: true,
            canCreateDirectories: true,
            directoryURL: directoryURL
        ) { url in
            Task { @MainActor in
                viewModel.setCustomLogDirectory(url)
            }
        }
    }
}
