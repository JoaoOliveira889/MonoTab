import SwiftUI

struct WindowThumbnailCard: View, Equatable {
    let window: WindowInfo
    let slot: ThumbnailSlot
    let isSelected: Bool
    let quickNumber: Int?
    let cardSize: CGSize
    let onSelect: () -> Void
    let onActivate: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false
    @Environment(\.monoReduceMotion) private var reduceMotion

    static func == (lhs: WindowThumbnailCard, rhs: WindowThumbnailCard) -> Bool {
        lhs.window.id == rhs.window.id
            && lhs.window.title == rhs.window.title
            && lhs.window.isMinimized == rhs.window.isMinimized
            && lhs.window.displayIndex == rhs.window.displayIndex
            && lhs.slot === rhs.slot
            && lhs.isSelected == rhs.isSelected
            && lhs.quickNumber == rhs.quickNumber
            && lhs.cardSize == rhs.cardSize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            preview
                .frame(width: cardSize.width, height: cardSize.height)
                .clipped()

            caption
                .frame(width: cardSize.width)
        }
        .padding(8)
        .contentShape(RoundedRectangle(cornerRadius: SwitcherMetrics.cardCornerRadius, style: .continuous))
        .selectionCard(
            isSelected: isSelected,
            isHovered: isHovered,
            cornerRadius: SwitcherMetrics.cardCornerRadius
        )
        .onHover { isHovered = $0 }
        .onTapGesture {
            onSelect()
            onActivate()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(window.appName), \(window.displayTitle)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.07))

            if let image = slot.image {
                Image(decorative: image, scale: 1, orientation: .up)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(3)
                    .transition(.opacity)
            } else {
                AppGlyph(pid: window.pid, appName: window.appName, iconSize: 44, showsName: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if isHovered || quickNumber != nil {
                VStack {
                    HStack {
                        if let quickNumber {
                            Text("\(quickNumber)")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 4.5)
                                .padding(.vertical, 2)
                                .surfaceTile(cornerRadius: 4)
                        }

                        Spacer()

                        if isHovered {
                            Button(action: onClose) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.primary)
                                    .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 1)
                            }
                            .buttonStyle(.plain)
                            .help("Close window (w)")
                            .accessibilityLabel("Close \(window.displayTitle)")
                        }
                    }
                    .padding(6)

                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .monoAnimation(.easeOut(duration: 0.18), value: slot.image == nil, enabled: !reduceMotion)
    }

    @ViewBuilder
    private var caption: some View {
        HStack(spacing: 8) {
            if let appIcon = AppIconCache.icon(for: window.pid) {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: "app.fill")
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(window.displayTitle)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    if window.isMinimized {
                        TagBadge(icon: "arrow.down.right.and.arrow.up.left", text: "minimized", tint: .orange)
                    }

                    if let display = window.displayIndex {
                        TagBadge(icon: "display", text: "\(display)", tint: .blue)
                    }
                }

                Text(window.appName)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }
}
