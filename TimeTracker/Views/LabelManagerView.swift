import SwiftUI
import AppKit

// MARK: - Window Controller

@MainActor
enum LabelManagerWindow {
    private static var window: NSWindow?

    static func show(viewModel: TimerViewModel) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let view = LabelManagerView(viewModel: viewModel, onDone: { close() })
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 400)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        w.title = "Timer Labels"
        w.contentView = hostingView
        w.center()
        w.level = .floating
        w.isReleasedWhenClosed = false
        w.minSize = NSSize(width: 250, height: 200)
        w.makeKeyAndOrderFront(nil)
        window = w
    }

    static func close() {
        window?.close()
        window = nil
    }
}

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
                    LabelRow(label: label, viewModel: viewModel)
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

            HStack {
                if isAddingLabel {
                    TextField("Label name", text: $newLabelName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { commitAdd() }

                    Button("Add") { commitAdd() }
                        .disabled(newLabelName.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button("Cancel") {
                        isAddingLabel = false
                        newLabelName = ""
                    }
                } else {
                    Button {
                        isAddingLabel = true
                    } label: {
                        Label("Add Label", systemImage: "plus")
                    }

                    Spacer()

                    Button("Done") { onDone() }
                }
            }
            .padding(10)
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

// MARK: - Label Row

private struct LabelRow: View {
    let label: TimerLabel
    let viewModel: TimerViewModel

    @State private var isEditing = false
    @State private var editName = ""
    @State private var isHovered = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack {
            if isEditing {
                TextField("Label name", text: $editName, onCommit: commitEdit)
                    .textFieldStyle(.roundedBorder)

                Button("Save") { commitEdit() }
                    .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Cancel") { isEditing = false }
            } else if showDeleteConfirmation {
                Text("Remove \"\(label.displayName)\"?")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("Remove") {
                    viewModel.deleteLabel(id: label.id)
                    showDeleteConfirmation = false
                }
                .foregroundStyle(.red)

                Button("Cancel") {
                    showDeleteConfirmation = false
                }
            } else {
                Text(label.displayName)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    editName = label.displayName
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
        viewModel.updateLabel(id: label.id, newDisplayName: trimmed)
        isEditing = false
    }
}
