import SwiftUI

private struct GlassPanelModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            content
                .background(shape.fill(.background))
                .overlay(shape.strokeBorder(Color.primary.opacity(0.18), lineWidth: 1))
                .clipShape(shape)
        } else {
            content
                .clipShape(shape)
                .glassEffect(.regular, in: shape)
        }
    }
}

private struct GlassBadgeModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Capsule().fill(Color.primary.opacity(0.08)))
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.16), lineWidth: 0.75))
        } else {
            content.glassEffect(.regular.interactive(), in: .capsule)
        }
    }
}

private struct GlassFieldModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.monoAccent) private var accent

    let isFocused: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        let border = shape.strokeBorder(
            isFocused ? accent.opacity(0.85) : Color.primary.opacity(0.12),
            lineWidth: isFocused ? 1.5 : 1
        )

        if reduceTransparency {
            content.background(shape.fill(Color.primary.opacity(0.06))).overlay(border)
        } else {
            content.glassEffect(.regular, in: shape).overlay(border)
        }
    }
}

private struct SelectionCardModifier: ViewModifier {
    @Environment(\.monoAccent) private var accent
    @Environment(\.monoReduceMotion) private var reduceMotion

    let isSelected: Bool
    let isHovered: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return content
            .background {
                ZStack {
                    shape.fill(
                        isSelected
                            ? accent.opacity(0.24)
                            : Color.primary.opacity(isHovered ? 0.08 : 0.035)
                    )

                    if isSelected {
                        shape.fill(
                            RadialGradient(
                                colors: [accent.opacity(0.32), .clear],
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
                    isSelected ? accent : Color.primary.opacity(isHovered ? 0.24 : 0.10),
                    lineWidth: isSelected ? 2 : 1
                )
            }
            .shadow(color: isSelected ? accent.opacity(0.35) : .clear, radius: 8, x: 0, y: 2)
            .monoAnimation(.easeOut(duration: 0.10), value: isSelected, enabled: !reduceMotion)
            .monoAnimation(.easeOut(duration: 0.10), value: isHovered, enabled: !reduceMotion)
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 22) -> some View {
        modifier(GlassPanelModifier(cornerRadius: cornerRadius))
    }

    func glassBadge() -> some View {
        modifier(GlassBadgeModifier())
    }

    func glassField(isFocused: Bool) -> some View {
        modifier(GlassFieldModifier(isFocused: isFocused))
    }

    func selectionCard(isSelected: Bool, isHovered: Bool, cornerRadius: CGFloat = 14) -> some View {
        modifier(SelectionCardModifier(isSelected: isSelected, isHovered: isHovered, cornerRadius: cornerRadius))
    }

    func surfaceTile(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(shape.fill(Color.primary.opacity(0.05)))
            .overlay(shape.strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.75))
    }
}
