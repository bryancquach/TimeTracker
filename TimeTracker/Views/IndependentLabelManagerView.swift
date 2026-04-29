import SwiftUI

// MARK: - Independent Label Manager View

struct IndependentLabelManagerView: View {
    let viewModel: TimerViewModel
    let onDone: () -> Void

    @State private var isAddingLabel = false
    @State private var newLabelName = ""
    @State private var newLinkedLabelId: TimerLabel.ID? = nil
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(viewModel.independentLabels) { label in
                    IndependentLabelRow(label: label, viewModel: viewModel)
                }
            }
            .listStyle(.plain)

            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Dismiss") { errorMessage = nil }
                        .font(.caption)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
            }

            Divider()

            AddLabelFooter(
                isAdding: $isAddingLabel,
                name: $newLabelName,
                addButtonTitle: "Add Independent Timer",
                onCommit: { commitAdd() },
                onCancel: {
                    isAddingLabel = false
                    newLabelName = ""
                    newLinkedLabelId = nil
                },
                onDone: onDone
            ) {
                Picker("Link to:", selection: $newLinkedLabelId) {
                    Text("None").tag(TimerLabel.ID?.none)
                    ForEach(viewModel.labels) { label in
                        Text(label.displayName).tag(TimerLabel.ID?.some(label.id))
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private func commitAdd() {
        let trimmed = newLabelName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            try viewModel.addIndependentLabel(displayName: trimmed, linkedLabelId: newLinkedLabelId)
            newLabelName = ""
            newLinkedLabelId = nil
            isAddingLabel = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Independent Label Row

private struct IndependentLabelRow: View {
    let label: IndependentTimerLabel
    let viewModel: TimerViewModel

    @State private var editLinkedLabelId: TimerLabel.ID? = nil

    var body: some View {
        EditableLabelRow(
            displayName: label.displayName,
            onSave: { newName in
                viewModel.updateIndependentLabel(
                    id: label.id,
                    newDisplayName: newName,
                    newLinkedLabelId: editLinkedLabelId
                )
            },
            onDelete: {
                viewModel.deleteIndependentLabel(id: label.id)
            },
            supplementaryEditContent: {
                Picker("Link to:", selection: $editLinkedLabelId) {
                    Text("None").tag(TimerLabel.ID?.none)
                    ForEach(viewModel.labels) { label in
                        Text(label.displayName).tag(TimerLabel.ID?.some(label.id))
                    }
                }
                .pickerStyle(.menu)
            },
            supplementaryDisplayContent: {
                if let linkedId = label.linkedLabelId,
                   let linkedName = viewModel.labels.first(where: { $0.id == linkedId })?.displayName {
                    Text("Linked to \(linkedName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        )
        .onAppear {
            editLinkedLabelId = label.linkedLabelId
        }
    }
}
