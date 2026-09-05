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
                        ? Color.accentColor.opacity(0.22)
                        : Color.primary.opacity(isHovered ? 0.09 : 0.04)
                )

                if isSelected {
                    shape.fill(
                        RadialGradient(
                            colors: [Color.accentColor.opacity(0.28), .clear],
                            center: .center,
                            startRadius: 15,
                            endRadius: 120
                        )
                    )
                }
            }
        }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                isSelected ? Color.accentColor.opacity(0.9) : Color.primary.opacity(isHovered ? 0.24 : 0.10),
                lineWidth: isSelected ? 2 : 1
            )
        }
        .scaleEffect(isSelected ? 1.025 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isSelected)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    func surfaceTile(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(shape.fill(Color.primary.opacity(0.05)))
            .overlay(shape.strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.75))
    }
}
