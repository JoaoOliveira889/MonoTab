import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    @Binding var isSearchMode: Bool
    let onExit: () -> Void
    @FocusState private var isFocused: Bool

    init(
        text: Binding<String>,
        isSearchMode: Binding<Bool>,
        onExit: @escaping () -> Void
    ) {
        self._text = text
        self._isSearchMode = isSearchMode
        self.onExit = onExit
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isFocused ? .accentColor : .secondary)
                .font(.system(size: 14, weight: .semibold))
                .animation(.easeInOut(duration: 0.15), value: isFocused)

            TextField("Search windows or apps... (Esc to exit)", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .regular))
                .focused($isFocused)
                .onTapGesture {
                    isSearchMode = true
                }

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
            }

            Button(action: onExit) {
                KeyCap("Esc")
            }
            .buttonStyle(.plain)
            .help("Exit search mode (Esc)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .glassField(isFocused: isFocused)
        .onAppear {
            if isSearchMode {
                isFocused = true
            }
        }
        .onChange(of: isSearchMode) { _, active in
            isFocused = active
        }
    }
}
