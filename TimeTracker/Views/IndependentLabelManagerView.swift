import SwiftUI
import AppKit

// MARK: - Window Controller

@MainActor
enum IndependentLabelManagerWindow {
    private static var window: NSWindow?

    static func show(viewModel: TimerViewModel) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let view = IndependentLabelManagerView(viewModel: viewModel, onDone: { close() })
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 350, height: 400)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        w.title = "Independent Timers"
        w.contentView = hostingView
        w.center()
        w.level = .floating
        w.isReleasedWhenClosed = false
        w.minSize = NSSize(width: 300, height: 200)
        w.makeKeyAndOrderFront(nil)
        window = w
    }

    static func close() {
        window?.close()
        window = nil
    }
}

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

            HStack {
                if isAddingLabel {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Label name", text: $newLabelName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { commitAdd() }

                        Picker("Link to:", selection: $newLinkedLabelId) {
                            Text("None").tag(TimerLabel.ID?.none)
                            ForEach(viewModel.labels) { label in
                                Text(label.displayName).tag(TimerLabel.ID?.some(label.id))
                            }
                        }
                        .pickerStyle(.menu)

                        HStack {
                            Button("Add") { commitAdd() }
                                .disabled(newLabelName.trimmingCharacters(in: .whitespaces).isEmpty)

                            Button("Cancel") {
                                isAddingLabel = false
                                newLabelName = ""
                                newLinkedLabelId = nil
                            }
                        }
                    }
                } else {
                    Button {
                        isAddingLabel = true
                    } label: {
                        Label("Add Independent Timer", systemImage: "plus")
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

    @State private var isEditing = false
    @State private var editName = ""
    @State private var editLinkedLabelId: TimerLabel.ID? = nil
    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack {
            if isEditing {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Label name", text: $editName, onCommit: commitEdit)
                        .textFieldStyle(.roundedBorder)

                    Picker("Link to:", selection: $editLinkedLabelId) {
                        Text("None").tag(TimerLabel.ID?.none)
                        ForEach(viewModel.labels) { label in
                            Text(label.displayName).tag(TimerLabel.ID?.some(label.id))
                        }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Button("Save") { commitEdit() }
                            .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)

                        Button("Cancel") { isEditing = false }
                    }
                }
            } else if showDeleteConfirmation {
                Text("Remove \"\(label.displayName)\"?")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("Remove") {
                    viewModel.deleteIndependentLabel(id: label.id)
                    showDeleteConfirmation = false
                }
                .foregroundStyle(.red)

                Button("Cancel") {
                    showDeleteConfirmation = false
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label.displayName)

                    if let linkedId = label.linkedLabelId,
                       let linkedName = viewModel.labels.first(where: { $0.id == linkedId })?.displayName {
                        Text("Linked to \(linkedName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    editName = label.displayName
                    editLinkedLabelId = label.linkedLabelId
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
        viewModel.updateIndependentLabel(id: label.id, newDisplayName: trimmed, newLinkedLabelId: editLinkedLabelId)
        isEditing = false
    }
}
