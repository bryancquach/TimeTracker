import SwiftUI

struct EditableLabelRow<EditContent: View, DisplayContent: View>: View {
    let displayName: String
    let onSave: (String) -> Void
    let onDelete: () -> Void
    @ViewBuilder var supplementaryEditContent: () -> EditContent
    @ViewBuilder var supplementaryDisplayContent: () -> DisplayContent

    @State private var isEditing = false
    @State private var editName = ""
    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack {
            if isEditing {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Label name", text: $editName, onCommit: commitEdit)
                        .textFieldStyle(.roundedBorder)

                    supplementaryEditContent()

                    HStack {
                        Button("Save") { commitEdit() }
                            .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)

                        Button("Cancel") { isEditing = false }
                    }
                }
            } else if showDeleteConfirmation {
                Text("Remove \"\(displayName)\"?")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("Remove") {
                    onDelete()
                    showDeleteConfirmation = false
                }
                .foregroundStyle(.red)

                Button("Cancel") {
                    showDeleteConfirmation = false
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)

                    supplementaryDisplayContent()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    editName = displayName
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }

    private func commitEdit() {
        let trimmed = editName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onSave(trimmed)
        isEditing = false
    }
}
