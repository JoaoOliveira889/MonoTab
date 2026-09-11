import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    @Binding var isSearchMode: Bool
    let onExit: () -> Void

    @FocusState private var isFocused: Bool
    @Environment(\.monoAccent) private var accent
    @Environment(\.monoReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(isFocused ? accent : Color.secondary)
                .font(.system(size: 14, weight: .semibold))
                .monoAnimation(.easeInOut(duration: 0.15), value: isFocused, enabled: !reduceMotion)

            TextField("Search windows or apps… (Esc to exit)", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .regular))
                .focused($isFocused)
                .onTapGesture { isSearchMode = true }

            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("Clear search")
                .accessibilityLabel("Clear search")
                .transition(.opacity.combined(with: .scale))
            }

            Button(action: onExit) {
                KeyCap("Esc")
            }
            .buttonStyle(.plain)
            .help("Exit search mode (Esc)")
            .accessibilityLabel("Exit search mode")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .glassField(isFocused: isFocused)
        .onAppear { isFocused = isSearchMode }
        .onChange(of: isSearchMode) { _, active in isFocused = active }
    }
}
