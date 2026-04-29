import SwiftUI

// MARK: - Label Manager View

struct LabelManagerView: View {
    let viewModel: TimerViewModel
    let onDone: () -> Void

    @State private var isAddingLabel = false
    @State private var newLabelName = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(viewModel.labels) { label in
                    EditableLabelRow(
                        displayName: label.displayName,
                        onSave: { newName in
                            viewModel.updateLabel(id: label.id, newDisplayName: newName)
                        },
                        onDelete: {
                            viewModel.deleteLabel(id: label.id)
                        },
                        supplementaryEditContent: { EmptyView() },
                        supplementaryDisplayContent: { EmptyView() }
                    )
                }
                .onMove { source, destination in
                    viewModel.moveLabel(from: source, to: destination)
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
                addButtonTitle: "Add Label",
                onCommit: { commitAdd() },
                onCancel: {
                    isAddingLabel = false
                    newLabelName = ""
                },
                onDone: onDone,
                supplementaryFields: { EmptyView() }
            )
        }
    }

    private func commitAdd() {
        let trimmed = newLabelName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            try viewModel.addLabel(displayName: trimmed)
            newLabelName = ""
            isAddingLabel = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
