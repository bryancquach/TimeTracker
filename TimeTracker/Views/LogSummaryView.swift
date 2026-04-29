import SwiftUI

// MARK: - Log Summary View

struct LogSummaryView: View {
    let viewModel: LogSummaryViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { viewModel.goBack() }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Time Tracking Summary")
                    .font(.headline)

                Spacer()

                Button(action: { viewModel.goForward() }) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canGoForward)
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(viewModel.days.enumerated()), id: \.offset) { _, entry in
                        DaySectionView(
                            day: entry.day,
                            result: entry.result,
                            allLabelIds: viewModel.allLabelIds,
                            allIndependentLabelIds: viewModel.allIndependentLabelIds,
                            displayName: { viewModel.displayName(for: $0) },
                            independentDisplayName: { viewModel.independentDisplayName(for: $0) }
                        )
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Day Section

private struct DaySectionView: View {
    let day: String
    let result: DayLogResult
    let allLabelIds: [TimerLabel.ID]
    let allIndependentLabelIds: [IndependentTimerLabel.ID]
    let displayName: (TimerLabel.ID) -> String
    let independentDisplayName: (IndependentTimerLabel.ID) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(day)
                .font(.title3.bold())

            switch result {
            case .loaded(let log):
                logTable(log)
            case .noData:
                Text("No log for this day.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            case .error(let message):
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Failed to load: \(message)")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }

            Divider()
        }
    }

    @ViewBuilder
    private func logTable(_ log: SessionLog) -> some View {
        let rawHoursWidth: CGFloat = 70
        let adjustedHoursWidth: CGFloat = 90
        let dayLabelIds = allLabelIds.filter { log.entries[$0] != nil }
        let dayIndLabelIds = allIndependentLabelIds.filter { log.independentTimerEntries[$0] != nil }

        if dayLabelIds.isEmpty && dayIndLabelIds.isEmpty {
            Text("No entries.")
                .foregroundStyle(.secondary)
                .font(.callout)
        } else {
            Grid(alignment: .leading, horizontalSpacing: 2, verticalSpacing: 4) {
                if !dayLabelIds.isEmpty {
                    GridRow {
                        Text("Label")
                            .bold()
                        Text("Raw hours")
                            .bold()
                            .frame(width: rawHoursWidth, alignment: .trailing)
                        Text("Adjusted hours")
                            .bold()
                            .frame(width: adjustedHoursWidth, alignment: .trailing)
                    }
                    .font(.callout)

                    Divider()

                    ForEach(dayLabelIds, id: \.self) { labelId in
                        if let entry = log.entries[labelId] {
                            GridRow {
                                Text(displayName(labelId))
                                    .font(.callout)
                                Text(String(format: "%.2f", entry.hours))
                                    .monospacedDigit()
                                    .font(.callout)
                                    .frame(width: rawHoursWidth, alignment: .trailing)
                                Text(String(format: "%.2f", entry.adjustedHours))
                                    .monospacedDigit()
                                    .font(.callout)
                                    .frame(width: adjustedHoursWidth, alignment: .trailing)
                            }
                        }
                    }
                }

                if !dayIndLabelIds.isEmpty {
                    Divider()

                    GridRow {
                        Text("Independent Timers")
                            .bold()
                            .italic()
                        Text("Raw hours")
                            .bold()
                            .frame(width: rawHoursWidth, alignment: .trailing)
                        Text("")
                            .frame(width: adjustedHoursWidth)
                    }
                    .font(.callout)

                    ForEach(dayIndLabelIds, id: \.self) { labelId in
                        if let hours = log.independentTimerEntries[labelId] {
                            GridRow {
                                Text(independentDisplayName(labelId))
                                    .font(.callout)
                                Text(String(format: "%.2f", hours))
                                    .monospacedDigit()
                                    .font(.callout)
                                    .frame(width: rawHoursWidth, alignment: .trailing)
                                Text("")
                                    .frame(width: adjustedHoursWidth)
                            }
                        }
                    }
                }
            }
        }
    }
}
