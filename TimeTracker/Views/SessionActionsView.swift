import SwiftUI
import AppKit

struct SessionActionsView: View {
    let showLogConfirmation: Bool
    let defaultLogFileName: String
    let onLogDefault: () -> Void
    let onLogToURL: (URL) -> Void
    let onReset: () -> Void
    let onUpdate: () -> Void

    @State private var showResetConfirmation = false
    @State private var showLogChoice = false

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Button("Log session") {
                    showLogChoice = true
                }
                .hoverHighlight(default: 0.05)
                .help("Save current session times to a log file")

                if showLogConfirmation {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }

                Spacer()

                Button("Update Past Entry") {
                    onUpdate()
                }
                .hoverHighlight(default: 0.05)
                .help("Recalculate adjusted hours for an existing log file if manual file changes were made to the raw hours")

                Spacer()

                Button("Reset") {
                    showResetConfirmation = true
                }
                .hoverHighlight(default: 0.05)
                .help("Zero out all timers for the current session")
            }
            .animation(.easeInOut(duration: 0.3), value: showLogConfirmation)

            if showLogChoice {
                HStack {
                    Text("Save to:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") {
                        showLogChoice = false
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    Button("Default") {
                        showLogChoice = false
                        onLogDefault()
                    }
                    .buttonStyle(.plain)
                    .font(.caption.bold())
                    Button("Choose\u{2026}") {
                        showLogChoice = false
                        showSavePanel()
                    }
                    .buttonStyle(.plain)
                    .font(.caption.bold())
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if showResetConfirmation {
                HStack {
                    Text("Zero out all timers?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") {
                        showResetConfirmation = false
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    Button("Reset") {
                        showResetConfirmation = false
                        onReset()
                    }
                    .buttonStyle(.plain)
                    .font(.caption.bold())
                    .foregroundStyle(.red)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showResetConfirmation)
        .animation(.easeInOut(duration: 0.2), value: showLogChoice)
    }

    private func showSavePanel() {
        let panel = NSSavePanel()
        panel.title = "Save Session Log"
        panel.nameFieldStringValue = defaultLogFileName
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.level = .floating
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                onLogToURL(url)
            }
        }
    }
}
