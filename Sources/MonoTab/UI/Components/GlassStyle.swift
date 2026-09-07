import SwiftUI

extension View {
    func glassPanel(cornerRadius: CGFloat = 22) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return clipShape(shape).glassEffect(.regular, in: shape)
    }

    func glassBadge() -> some View {
        glassEffect(.regular.interactive(), in: .capsule)
    }

    func glassField(isFocused: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return glassEffect(.regular, in: shape)
            .overlay {
                shape.strokeBorder(
                    isFocused ? Color.accentColor.opacity(0.85) : Color.primary.opacity(0.12),
                    lineWidth: isFocused ? 1.5 : 1
                )
            }
    }

    func selectionCard(isSelected: Bool, isHovered: Bool, cornerRadius: CGFloat = 14) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return background {
            ZStack {
                shape.fill(
                    isSelected
                        ? Color.accentColor.opacity(0.24)
                        : Color.primary.opacity(isHovered ? 0.08 : 0.035)
                )

                if isSelected {
                    shape.fill(
                        RadialGradient(
                            colors: [Color.accentColor.opacity(0.32), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 130
                        )
                    )
                }
            }
        }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                isSelected ? Color.accentColor : Color.primary.opacity(isHovered ? 0.24 : 0.10),
                lineWidth: isSelected ? 2 : 1
            )
        }
        .shadow(
            color: isSelected ? Color.accentColor.opacity(0.35) : Color.clear,
            radius: 8,
            x: 0,
            y: 2
        )
        .animation(.easeOut(duration: 0.10), value: isSelected)
        .animation(.easeOut(duration: 0.10), value: isHovered)
    }

    func surfaceTile(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(shape.fill(Color.primary.opacity(0.05)))
            .overlay(shape.strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.75))
    }
}
