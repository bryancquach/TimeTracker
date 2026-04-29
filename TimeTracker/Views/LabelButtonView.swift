import SwiftUI

struct LabelButtonView: View {
    let id: String
    let displayName: String
    let isActive: Bool
    let elapsed: String
    var helpText: String? = nil
    let action: () -> Void
    var onIncrement: (() -> Void)? = nil
    var onDecrement: (() -> Void)? = nil

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: isActive ? "circle.fill" : "circle")
                        .foregroundStyle(isActive ? .green : .secondary)
                        .font(.system(size: 8))

                    Text(displayName)
                        .fontWeight(isActive ? .semibold : .regular)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            if let onDecrement {
                Button(action: onDecrement) {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .hoverHighlight(hover: 0.08, horizontalPadding: 2, verticalPadding: 2, cornerRadius: 4)
            }

            Text(elapsed)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            if let onIncrement {
                Button(action: onIncrement) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .hoverHighlight(hover: 0.08, horizontalPadding: 2, verticalPadding: 2, cornerRadius: 4)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(isHovered ? Color.primary.opacity(0.08) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in isHovered = hovering }
        .help(helpText ?? "")
    }
}
