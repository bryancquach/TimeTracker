import SwiftUI

struct HoverHighlight: ViewModifier {
    var color: Color = .primary
    var defaultOpacity: Double = 0
    var hoverOpacity: Double = 0.12
    var horizontalPadding: CGFloat = 8
    var verticalPadding: CGFloat = 4
    var cornerRadius: CGFloat = 6
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(color.opacity(isHovered ? hoverOpacity : defaultOpacity))
            .cornerRadius(cornerRadius)
            .onHover { isHovered = $0 }
    }
}

extension View {
    func hoverHighlight(
        color: Color = .primary,
        default defaultOpacity: Double = 0,
        hover hoverOpacity: Double = 0.12,
        horizontalPadding: CGFloat = 8,
        verticalPadding: CGFloat = 4,
        cornerRadius: CGFloat = 6
    ) -> some View {
        modifier(HoverHighlight(
            color: color,
            defaultOpacity: defaultOpacity,
            hoverOpacity: hoverOpacity,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            cornerRadius: cornerRadius
        ))
    }
}
