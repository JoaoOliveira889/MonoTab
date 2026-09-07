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
        isFullscreen || viewModel.isSettingsOpen || viewModel.isPreviewOpen
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
                minWidth: isFullscreen ? 1080 : min(860, max(680, CGFloat(columnCount) * (cardWidth + 20) + 72)),
                maxWidth: isFullscreen
                    ? min(2050, max(1080, CGFloat(columnCount) * (cardWidth + 24) + 100))
                    : min(1600, max(860, CGFloat(columnCount) * (cardWidth + 20) + 80))
            )
            .glassPanel(cornerRadius: 24)
            .shadow(color: Color.black.opacity(0.42), radius: 30, x: 0, y: 15)

            if viewModel.isPreviewOpen, let selected = viewModel.selectedWindow {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { viewModel.closePreview() }

                QuickLookView(
                    window: selected,
                    slot: viewModel.slot(for: selected.id),
                    onClose: { viewModel.closePreview() },
                    onConfirm: onConfirm
                )
                .transition(.scale(scale: 0.94).combined(with: .opacity))
                .zIndex(15)
            }

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
        .animation(.smooth(duration: 0.22), value: isFullscreen)
        .animation(.smooth(duration: 0.18), value: viewModel.isSearchMode)
        .animation(.smooth(duration: 0.20), value: viewModel.isPreviewOpen)
        .animation(.smooth(duration: 0.18), value: viewModel.isSettingsOpen)
        .onChange(of: coversScreen) { _, _ in onLayoutChange() }
        .onChange(of: preferences.displayMode) { _, _ in onLayoutChange() }
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
            if viewModel.isPreviewOpen {
                viewModel.closePreview()
            } else if viewModel.isSettingsOpen {
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

                if viewModel.isAppOnlyMode {
                    Text("App Only")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.blue.opacity(0.18))
                        .overlay(Capsule().strokeBorder(Color.blue.opacity(0.35), lineWidth: 0.5))
                        .clipShape(Capsule())
                        .foregroundColor(.blue)
                }
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
                    withAnimation(.smooth(duration: 0.22)) {
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
                            ForEach(Array(windows.enumerated()), id: \.element.id) { index, window in
                                WindowThumbnailCard(
                                    window: window,
                                    slot: viewModel.slot(for: window.id),
                                    isSelected: window.id == selectedID,
                                    index: index,
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
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color.black.opacity(0.18), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 8)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.18)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 8)
                .allowsHitTesting(false)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: viewModel.maxGridHeight)
            .fixedSize(horizontal: false, vertical: true)
            .onChange(of: selectedID) { _, newID in
                guard let newID else { return }
                withAnimation(.smooth(duration: 0.15)) {
                    proxy.scrollTo(newID)
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

private struct QuickLookView: View {
    let window: WindowInfo
    let slot: ThumbnailSlot
    let onClose: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                if let appIcon = AppIconCache.icon(for: window.pid) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(window.displayTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(window.appName)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)

                        if window.isMinimized {
                            Text("Minimized")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.orange)
                        }

                        if let display = window.displayIndex {
                            Text("Display \(display)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    }
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close preview (Space / Esc)")
            }

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.35))

                if let image = slot.image {
                    Image(decorative: image, scale: 1, orientation: .up)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(6)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "macwindow")
                            .font(.system(size: 44, weight: .light))
                            .foregroundColor(.secondary)
                        Text(window.appName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(minWidth: 480, maxWidth: 760, minHeight: 320, maxHeight: 480)

            HStack {
                HStack(spacing: 10) {
                    ShortcutHint(key: "Space", description: "Close Preview")
                    ShortcutHint(key: "⏎", description: "Switch to Window")
                    ShortcutHint(key: "w", description: "Close")
                    ShortcutHint(key: "m", description: "Min")
                    ShortcutHint(key: "z", description: "Zoom")
                }

                Spacer()

                Button("Switch to Window", action: onConfirm)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
            }
        }
        .padding(18)
        .glassPanel(cornerRadius: 20)
        .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 12)
    }
}

private struct ShortcutLegend: View {
    let shortcut: ShortcutPreference
    let isFullscreen: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Grupo 1: Navegação principal
            HStack(spacing: 7) {
                ShortcutHint(key: "↑↓←→ / hjkl", description: "Navegar")
                ShortcutHint(key: "1-9", description: "Pular")
                ShortcutHint(key: "Espaço", description: "Prévia")
            }

            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(width: 1, height: 12)

            // Grupo 2: Ações de janela
            HStack(spacing: 7) {
                ShortcutHint(key: "w", description: "Fechar")
                ShortcutHint(key: "m", description: "Min")
                ShortcutHint(key: "z", description: "Zoom")
                ShortcutHint(key: "⌘Q", description: "Encerrar")
                ShortcutHint(key: "f", description: "Buscar")
            }

            Spacer(minLength: 8)

            // Grupo 3 (Final dos atalhos): Confirmação, Saída e Indicador de Modo
            HStack(spacing: 8) {
                ShortcutHint(key: "⏎ Enter", description: "Abrir")
                ShortcutHint(key: "⎋ Esc", description: "Sair")

                HStack(spacing: 4) {
                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 8, weight: .bold))
                    Text(isFullscreen ? "Fullscreen" : "Floating")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .surfaceTile(cornerRadius: 4)
            }
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
