import AppKit
import SwiftUI

public struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

public struct LiquidGlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    public init(cornerRadius: CGFloat = 22) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)

                    // Ambient depth layer
                    if colorScheme == .dark {
                        Color.black.opacity(0.35)
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.clear,
                                Color.black.opacity(0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color.white.opacity(0.40)
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.clear,
                                Color.black.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(colorScheme == .dark ? 0.35 : 0.60), location: 0.0),
                                .init(color: Color.white.opacity(colorScheme == .dark ? 0.10 : 0.25), location: 0.25),
                                .init(color: Color.white.opacity(0.04), location: 0.75),
                                .init(color: Color.white.opacity(colorScheme == .dark ? 0.12 : 0.30), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
    }
}

public extension View {
    func liquidGlassPanel(cornerRadius: CGFloat = 22) -> some View {
        self.modifier(LiquidGlassPanelModifier(cornerRadius: cornerRadius))
    }

    func liquidGlassCard(isSelected: Bool, isHovered: Bool, cornerRadius: CGFloat = 14) -> some View {
        self
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            isSelected
                                ? Color.accentColor.opacity(0.22)
                                : (isHovered ? Color.white.opacity(0.10) : Color.white.opacity(0.04))
                        )

                    if isSelected {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.28),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 15,
                                    endRadius: 120
                                )
                            )
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.95),
                                    Color.accentColor.opacity(0.55)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                              )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(isHovered ? 0.30 : 0.12),
                                    Color.white.opacity(isHovered ? 0.10 : 0.03)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                              ),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.025 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isSelected)
            .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    func liquidGlassSearchBar(isFocused: Bool) -> some View {
        self
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.50))

                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.06), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isFocused
                            ? LinearGradient(
                                colors: [Color.accentColor.opacity(0.85), Color.accentColor.opacity(0.45)],
                                startPoint: .top,
                                endPoint: .bottom
                              )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.20), Color.white.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                              ),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
    }

    func liquidGlassBadge() -> some View {
        self
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.24), Color.white.opacity(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.75
                    )
            )
    }
}
