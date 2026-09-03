import SwiftUI

public struct WindowThumbnailCard: View {
    let window: WindowInfo
    let thumbnail: NSImage?
    let isSelected: Bool
    let onSelect: () -> Void
    let onActivate: () -> Void

    @State private var isHovered: Bool = false

    public init(
        window: WindowInfo,
        thumbnail: NSImage?,
        isSelected: Bool,
        onSelect: @escaping () -> Void,
        onActivate: @escaping () -> Void
    ) {
        self.window = window
        self.thumbnail = thumbnail
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onActivate = onActivate
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.20))

                if let thumb = thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(3)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    VStack(spacing: 8) {
                        if let icon = window.appIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 44, height: 44)
                                .shadow(color: Color.black.opacity(0.25), radius: 5, x: 0, y: 2)
                        } else {
                            Image(systemName: "macwindow")
                                .font(.system(size: 30, weight: .light))
                                .foregroundColor(.secondary)
                        }

                        Text(window.appName)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 248, height: 154)
            .clipped()

            HStack(spacing: 8) {
                if let icon = window.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                        .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                } else {
                    Image(systemName: "app.fill")
                        .frame(width: 22, height: 22)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(window.displayTitle)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                            .lineLimit(1)
                            .foregroundColor(.primary)

                        if window.isMinimized {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    .font(.system(size: 7.5, weight: .bold))
                                Text("minimized")
                                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.18))
                            .overlay(Capsule().strokeBorder(Color.orange.opacity(0.35), lineWidth: 0.5))
                            .clipShape(Capsule())
                            .foregroundColor(.orange)
                        }
                    }

                    Text(window.appName)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .frame(width: 248)
        }
        .padding(8)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .liquidGlassCard(isSelected: isSelected, isHovered: isHovered, cornerRadius: 14)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
            onActivate()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(window.appName), \(window.displayTitle)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .animation(.easeOut(duration: 0.18), value: thumbnail != nil)
    }
}
