import SwiftUI

struct AddLabelFooter<SupplementaryFields: View>: View {
    @Binding var isAdding: Bool
    @Binding var name: String
    let addButtonTitle: String
    let onCommit: () -> Void
    let onCancel: () -> Void
    let onDone: () -> Void
    @ViewBuilder var supplementaryFields: () -> SupplementaryFields

    var body: some View {
        HStack {
            if isAdding {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Label name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { onCommit() }

                    supplementaryFields()

                    HStack {
                        Button("Add") { onCommit() }
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)

                        Button("Cancel") { onCancel() }
                    }
                }
            } else {
                Button {
                    isAdding = true
                } label: {
                    Label(addButtonTitle, systemImage: "plus")
                }

                Spacer()

                Button("Done") { onDone() }
            }
        }
        .padding(10)
    }
}
