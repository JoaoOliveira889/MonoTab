import SwiftUI

struct WindowThumbnailCard: View {
    let window: WindowInfo
    let slot: ThumbnailSlot
    let isSelected: Bool
    let index: Int?
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let onSelect: () -> Void
    let onActivate: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false

    init(
        window: WindowInfo,
        slot: ThumbnailSlot,
        isSelected: Bool,
        index: Int? = nil,
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        onSelect: @escaping () -> Void,
        onActivate: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.window = window
        self.slot = slot
        self.isSelected = isSelected
        self.index = index
        self.cardWidth = cardWidth
        self.cardHeight = cardHeight
        self.onSelect = onSelect
        self.onActivate = onActivate
        self.onClose = onClose
    }

    private var appIcon: NSImage? {
        AppIconCache.icon(for: window.pid)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            preview
                .frame(width: cardWidth, height: cardHeight)
                .clipped()

            caption
                .frame(width: cardWidth)
        }
        .padding(8)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .selectionCard(isSelected: isSelected, isHovered: isHovered, cornerRadius: 14)
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
                .fill(Color.black.opacity(0.20))

            if let image = slot.image {
                Image(decorative: image, scale: 1, orientation: .up)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(3)
                    .transition(.opacity)
            } else {
                placeholder
            }

            if isHovered || (index != nil && index! < 9 && PreferencesManager.shared.showQuickShortcuts) {
                VStack {
                    HStack {
                        if let index, index < 9, PreferencesManager.shared.showQuickShortcuts {
                            QuickKeyBadge(number: index + 1)
                        }

                        Spacer()

                        if isHovered {
                            Button(action: onClose) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.85))
                                    .shadow(color: Color.black.opacity(0.5), radius: 3, x: 0, y: 1)
                            }
                            .buttonStyle(.plain)
                            .help("Close window (w)")
                        }
                    }
                    .padding(6)

                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: slot.image == nil)
    }

    @ViewBuilder
    private var placeholder: some View {
        VStack(spacing: 8) {
            if let appIcon {
                Image(nsImage: appIcon)
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

    @ViewBuilder
    private var caption: some View {
        HStack(spacing: 8) {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
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
                        MinimizedBadge()
                    }

                    if let display = window.displayIndex {
                        DisplayBadge(index: display)
                    }
                }

                Text(window.appName)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct QuickKeyBadge: View {
    let number: Int

    var body: some View {
        Text("\(number)")
            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
            .foregroundColor(.primary)
            .padding(.horizontal, 4.5)
            .padding(.vertical, 2)
            .surfaceTile(cornerRadius: 4)
            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
}

private struct DisplayBadge: View {
    let index: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "display")
                .font(.system(size: 6.5))
            Text("\(index)")
                .font(.system(size: 8, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1.5)
        .background(Color.blue.opacity(0.16))
        .overlay(Capsule().strokeBorder(Color.blue.opacity(0.35), lineWidth: 0.5))
        .clipShape(Capsule())
        .foregroundColor(.blue)
    }
}

private struct MinimizedBadge: View {
    var body: some View {
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

