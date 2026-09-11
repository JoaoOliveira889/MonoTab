import SwiftUI

struct HelpOverlayView: View {
    let onClose: () -> Void

    @Environment(\.monoAccent) private var accent

    private let columns = [
        GridItem(.flexible(), spacing: 22, alignment: .topLeading),
        GridItem(.flexible(), spacing: 22, alignment: .topLeading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accent)

                Text("Keyboard Shortcuts")
                    .font(.system(size: 15, weight: .bold, design: .rounded))

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close shortcuts (? or Esc)")
                .accessibilityLabel("Close shortcuts")
            }

            Divider().opacity(0.25)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                    ForEach(ShortcutCatalog.groups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.title.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary.opacity(0.85))

                            VStack(alignment: .leading, spacing: 7) {
                                ForEach(group.items) { item in
                                    ShortcutHint(item)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .surfaceTile(cornerRadius: 12)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: SwitcherMetrics.helpSize.width)
        .frame(maxHeight: SwitcherMetrics.helpSize.height)
        .glassPanel(cornerRadius: 20)
        .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 12)
    }
}
