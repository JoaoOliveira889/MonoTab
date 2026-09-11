import SwiftUI

struct KeyCap: View {
    let label: String
    let size: CGFloat

    init(_ label: String, size: CGFloat = 10) {
        self.label = label
        self.size = size
    }

    var body: some View {
        Text(label)
            .font(.system(size: size, weight: .bold, design: .monospaced))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .surfaceTile(cornerRadius: 4)
            .foregroundStyle(.primary)
    }
}

struct ShortcutHint: View {
    let key: String
    let description: String

    init(key: String, description: String) {
        self.key = key
        self.description = description
    }

    init(_ item: ShortcutItem) {
        self.key = item.key
        self.description = item.description
    }

    var body: some View {
        HStack(spacing: 5) {
            KeyCap(key)
            Text(description)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(key): \(description)")
    }
}

struct TagBadge: View {
    let icon: String?
    let text: String
    let tint: Color
    let size: CGFloat

    init(icon: String? = nil, text: String, tint: Color, size: CGFloat = 8.5) {
        self.icon = icon
        self.text = text
        self.tint = tint
        self.size = size
    }

    var body: some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: size - 1.5, weight: .bold))
            }
            Text(text)
                .font(.system(size: size, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(tint.opacity(0.16))
        .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 0.5))
        .clipShape(Capsule())
        .foregroundStyle(tint)
    }
}

struct AppGlyph: View {
    let pid: pid_t
    let appName: String
    let iconSize: CGFloat
    let showsName: Bool

    var body: some View {
        VStack(spacing: 8) {
            if let icon = AppIconCache.icon(for: pid) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .shadow(color: Color.black.opacity(0.25), radius: 5, x: 0, y: 2)
            } else {
                Image(systemName: "macwindow")
                    .font(.system(size: iconSize * 0.68, weight: .light))
                    .foregroundStyle(.secondary)
            }

            if showsName {
                Text(appName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
