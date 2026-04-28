import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    let viewModel: TimerViewModel
    @State private var isDecrementHovered = false
    @State private var isIncrementHovered = false
    @State private var isChooseHovered = false
    @State private var isManageLabelsHovered = false
    @State private var isManageIndependentHovered = false
    @State private var isClearHovered = false
    @State private var isExportHovered = false
    @State private var isImportHovered = false
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
                .buttonStyle(.plain)
                .padding(2)
                .background(Color.primary.opacity(isDecrementHovered ? 0.08 : 0))
                .cornerRadius(4)
                .onHover { isDecrementHovered = $0 }

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
                .buttonStyle(.plain)
                .padding(2)
                .background(Color.primary.opacity(isIncrementHovered ? 0.08 : 0))
                .cornerRadius(4)
                .onHover { isIncrementHovered = $0 }
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
                    .buttonStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(isChooseHovered ? 0.08 : 0))
                    .cornerRadius(4)
                    .onHover { isChooseHovered = $0 }
                }

                Button("Choose\u{2026}") {
                    showDirectoryPicker()
                }
                .buttonStyle(.plain)
                .font(.callout.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(isChooseHovered ? 0.08 : 0))
                .cornerRadius(4)
                .onHover { isChooseHovered = $0 }
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
                    LabelManagerWindow.show(viewModel: viewModel)
                }
                .buttonStyle(.plain)
                .font(.callout.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(isManageLabelsHovered ? 0.08 : 0))
                .cornerRadius(4)
                .onHover { isManageLabelsHovered = $0 }

                Spacer()
            }

            HStack {
                Button("Manage Independent Timers\u{2026}") {
                    IndependentLabelManagerWindow.show(viewModel: viewModel)
                }
                .buttonStyle(.plain)
                .font(.callout.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(isManageIndependentHovered ? 0.08 : 0))
                .cornerRadius(4)
                .onHover { isManageIndependentHovered = $0 }

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
                    .buttonStyle(.plain)
                    .font(.callout.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(isClearHovered ? 0.08 : 0))
                    .cornerRadius(4)
                    .onHover { isClearHovered = $0 }

                    Button("Export\u{2026}") {
                        exportData()
                    }
                    .buttonStyle(.plain)
                    .font(.callout.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(isExportHovered ? 0.08 : 0))
                    .cornerRadius(4)
                    .onHover { isExportHovered = $0 }

                    Button("Import\u{2026}") {
                        importData()
                    }
                    .buttonStyle(.plain)
                    .font(.callout.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(isImportHovered ? 0.08 : 0))
                    .cornerRadius(4)
                    .onHover { isImportHovered = $0 }
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
        guard let bundle = viewModel.exportData() else { return }
        guard let data = try? JSONCoding.encoder.encode(bundle) else { return }

        let panel = NSSavePanel()
        panel.title = "Export App Data"
        panel.nameFieldStringValue = "TimeTracker-export.json"
        panel.allowedContentTypes = [.json]
        panel.level = .floating
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    private func importData() {
        let panel = NSOpenPanel()
        panel.title = "Import App Data"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        panel.level = .floating
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
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
        let panel = NSOpenPanel()
        panel.title = "Select Log Output Directory"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.level = .floating
        if let current = viewModel.customLogDirectoryPath {
            panel.directoryURL = URL(fileURLWithPath: current, isDirectory: true)
        } else {
            panel.directoryURL = viewModel.logsDirectoryURL
        }
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                viewModel.setCustomLogDirectory(url)
            }
        }
    }
}
