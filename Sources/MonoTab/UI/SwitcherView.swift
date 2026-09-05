import SwiftUI

struct SwitcherView: View {
    @Bindable var viewModel: SwitcherViewModel
    @Bindable private var preferences = PreferencesManager.shared

    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onLayoutChange: () -> Void

    init(
        viewModel: SwitcherViewModel,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onLayoutChange: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.onLayoutChange = onLayoutChange
    }

    private var isFullscreen: Bool {
        preferences.displayMode == .fullscreen
    }

    private var cardWidth: CGFloat { isFullscreen ? 278 : 264 }
    private var cardHeight: CGFloat { isFullscreen ? 172 : 162 }

    private var coversScreen: Bool {
        isFullscreen || viewModel.isSettingsOpen
    }

    var body: some View {
        let columnCount = viewModel.columnCount(isFullscreen: isFullscreen)

        ZStack {
            if coversScreen {
                backdrop
            }

            VStack(spacing: 12) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 16)

                if viewModel.isSearchMode {
                    SearchBarView(
                        text: $viewModel.searchQuery,
                        isSearchMode: $viewModel.isSearchMode,
                        onExit: { withAnimation(.easeInOut(duration: 0.18)) { viewModel.exitSearchMode() } }
                    )
                    .padding(.horizontal, 18)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                PermissionsBannerView()
                    .padding(.horizontal, 18)

                WindowGrid(
                    viewModel: viewModel,
                    columnCount: columnCount,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    isFullscreen: isFullscreen,
                    onConfirm: onConfirm
                )

                ShortcutLegend(shortcut: preferences.shortcut, isFullscreen: isFullscreen)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
                    .padding(.top, 2)
            }
            .frame(
                minWidth: isFullscreen ? 1080 : 860,
                maxWidth: isFullscreen
                    ? min(2050, max(1080, CGFloat(columnCount) * (cardWidth + 24) + 100))
                    : min(1600, max(860, CGFloat(columnCount) * (cardWidth + 20) + 80))
            )
            .glassPanel(cornerRadius: 24)
            .shadow(color: Color.black.opacity(0.42), radius: 30, x: 0, y: 15)

            if viewModel.isSettingsOpen {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { dismissSettings() }

                SettingsView(onClose: dismissSettings)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .frame(
            maxWidth: coversScreen ? .infinity : nil,
            maxHeight: coversScreen ? .infinity : nil
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isFullscreen)
        .animation(.spring(response: 0.24, dampingFraction: 0.8), value: viewModel.isSearchMode)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isSettingsOpen)
        .onChange(of: coversScreen) { _, _ in onLayoutChange() }
        .onChange(of: viewModel.filteredWindows.count) { _, _ in onLayoutChange() }
    }

    @ViewBuilder
    private var backdrop: some View {
        Group {
            if isFullscreen {
                Color.black.opacity(0.20)
            } else {
                Color.clear.contentShape(Rectangle())
            }
        }
        .ignoresSafeArea()
        .onTapGesture {
            if viewModel.isSettingsOpen {
                dismissSettings()
            } else if viewModel.isSearchMode {
                viewModel.exitSearchMode()
            } else {
                onCancel()
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Image(systemName: "macwindow.on.rectangle")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.accentColor)

                Text("MonoTab")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }

            Spacer()

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    let count = viewModel.filteredWindows.count
                Text("\(count) \(count == 1 ? "window" : "windows")")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .glassBadge()
                    .foregroundColor(.secondary)

                if !viewModel.isSearchMode {
                    Button {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
                            viewModel.enterSearchMode()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Search")
                                .font(.system(size: 11, weight: .medium))
                            KeyCap("f", size: 9)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassBadge()
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Search windows (Press 'f' or '/')")
                }

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        preferences.toggleDisplayMode()
                    }
                } label: {
                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(6)
                        .glassBadge()
                }
                .buttonStyle(.plain)
                .help(isFullscreen ? "Switch to floating mode" : "Expand to fullscreen")

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        viewModel.toggleSettings()
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(6)
                        .glassBadge()
                }
                    .buttonStyle(.plain)
                    .help("Preferences")
                }
            }
        }
    }

    private func dismissSettings() {
        withAnimation {
            viewModel.closeSettings()
            onCancel()
        }
    }
}

private struct WindowGrid: View {
    let viewModel: SwitcherViewModel
    let columnCount: Int
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let isFullscreen: Bool
    let onConfirm: () -> Void

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: cardWidth - 8, maximum: cardWidth + 30), spacing: 16),
            count: columnCount
        )
    }

    var body: some View {
        let windows = viewModel.filteredWindows
        let selectedID = viewModel.selectedWindow?.id

        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    if windows.isEmpty {
                        EmptyState()
                    } else {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(windows) { window in
                                WindowThumbnailCard(
                                    window: window,
                                    slot: viewModel.slot(for: window.id),
                                    isSelected: window.id == selectedID,
                                    cardWidth: cardWidth,
                                    cardHeight: cardHeight,
                                    onSelect: { viewModel.select(id: window.id) },
                                    onActivate: onConfirm,
                                    onClose: { SwitcherPanelController.shared.close(window: window) }
                                )
                                .id(window.id)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: viewModel.maxGridHeight)
            .fixedSize(horizontal: false, vertical: true)
            .onChange(of: selectedID) { _, newID in
                guard let newID else { return }
                withAnimation(.easeInOut(duration: 0.14)) {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No windows found")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
            Text("Press Esc to clear search or cancel")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}

private struct ShortcutLegend: View {
    let shortcut: ShortcutPreference
    let isFullscreen: Bool

    private var cycleLabel: String {
        switch shortcut {
        case .commandTab: "⌘ ⇥"
        case .optionTab: "⌥ ⇥"
        case .both: "⌥ / ⌘ ⇥"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ShortcutHint(key: cycleLabel, description: "Next")
            ShortcutHint(key: "⇧ + ⇥", description: "Back")
            ShortcutHint(key: "↑ ↓ ← → / hjkl", description: "Navigate")
            ShortcutHint(key: "w", description: "Close")
            ShortcutHint(key: "⌘Q", description: "Quit app")
            ShortcutHint(key: "f or /", description: "Search")
            ShortcutHint(key: "⏎", description: "Select")
            ShortcutHint(key: "⎋", description: "Dismiss")

            Spacer()

            Text(isFullscreen ? "Fullscreen Mode" : "Floating Mode")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary.opacity(0.8))
        }
    }
}

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
            .foregroundColor(.primary)
    }
}

struct ShortcutHint: View {
    let key: String
    let description: String

    var body: some View {
        HStack(spacing: 5) {
            KeyCap(key)
            Text(description)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.secondary)
        }
    }
}
