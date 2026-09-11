import SwiftUI

struct SwitcherView: View {
    @Bindable var viewModel: SwitcherViewModel
    @Bindable private var preferences = PreferencesManager.shared

    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onLayoutChange: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    private var accent: Color {
        preferences.accent.color
    }

    private var cardSize: CGSize {
        SwitcherMetrics.card(isFullscreen: isFullscreen)
    }

    var body: some View {
        ZStack {
            if isFullscreen {
                backdrop
            }

            if let sheet = viewModel.activeSheet, !isFullscreen {
                sheetView(sheet)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            } else {
                mainPanel
            }

            if isFullscreen, let sheet = viewModel.activeSheet {
                dimmingLayer(opacity: 0.45) { handleBackdropTap() }
                sheetView(sheet)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                    .zIndex(10)
            }

            if let confirmation = viewModel.pendingConfirmation {
                dimmingLayer(opacity: 0.5) { viewModel.pendingConfirmation = nil }
                ConfirmationOverlayView(
                    confirmation: confirmation,
                    onConfirm: {
                        viewModel.pendingConfirmation = nil
                        confirmation.perform()
                    },
                    onCancel: { viewModel.pendingConfirmation = nil }
                )
                .transition(.scale(scale: 0.94).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .frame(
            maxWidth: isFullscreen ? .infinity : nil,
            maxHeight: isFullscreen ? .infinity : nil
        )
        .environment(\.monoAccent, accent)
        .environment(\.monoReduceMotion, reduceMotion)
        .tint(accent)
        .monoAnimation(.smooth(duration: 0.22), value: isFullscreen, enabled: !reduceMotion)
        .monoAnimation(.smooth(duration: 0.18), value: viewModel.isSearchMode, enabled: !reduceMotion)
        .monoAnimation(.smooth(duration: 0.20), value: viewModel.activeSheet != nil, enabled: !reduceMotion)
        .monoAnimation(.smooth(duration: 0.18), value: viewModel.pendingConfirmation?.id, enabled: !reduceMotion)
        .onChange(of: viewModel.activeSheet != nil) { _, _ in onLayoutChange() }
        .onChange(of: preferences.displayMode) { _, _ in onLayoutChange() }
        .onChange(of: viewModel.isSearchMode) { _, _ in onLayoutChange() }
        .onChange(of: viewModel.filteredWindows.count) { _, _ in onLayoutChange() }
    }

    @ViewBuilder
    private func sheetView(_ sheet: SwitcherSheet) -> some View {
        switch sheet {
        case .settings:
            SettingsView(onClose: { viewModel.closeSettings() })
        case .help:
            HelpOverlayView(onClose: { viewModel.closeHelp() })
        case .preview:
            if let selected = viewModel.selectedWindow {
                QuickLookView(
                    window: selected,
                    slot: viewModel.slot(for: selected.id),
                    onClose: { viewModel.closePreview() },
                    onConfirm: onConfirm
                )
            }
        }
    }

    private var mainPanel: some View {
        let columnCount = viewModel.columnCount(isFullscreen: isFullscreen)

        return VStack(spacing: 12) {
            header
                .padding(.horizontal, SwitcherMetrics.gridHorizontalPadding)
                .padding(.top, 16)

            if viewModel.isSearchMode {
                SearchBarView(
                    text: $viewModel.searchQuery,
                    isSearchMode: $viewModel.isSearchMode,
                    onExit: { viewModel.exitSearchMode() }
                )
                .padding(.horizontal, SwitcherMetrics.gridHorizontalPadding)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            PermissionsBannerView()
                .padding(.horizontal, SwitcherMetrics.gridHorizontalPadding)

            WindowGrid(
                viewModel: viewModel,
                columnCount: columnCount,
                cardSize: cardSize,
                onConfirm: onConfirm
            )

            ShortcutLegend(isFullscreen: isFullscreen)
                .padding(.horizontal, SwitcherMetrics.gridHorizontalPadding)
                .padding(.bottom, 14)
                .padding(.top, 2)
        }
        .frame(
            minWidth: isFullscreen
                ? 1080
                : min(860, max(680, SwitcherMetrics.contentWidth(columns: columnCount, isFullscreen: false) - 40)),
            maxWidth: isFullscreen
                ? min(SwitcherMetrics.maxFullscreenWidth, max(1080, SwitcherMetrics.contentWidth(columns: columnCount, isFullscreen: true)))
                : min(SwitcherMetrics.maxFloatingWidth, max(860, SwitcherMetrics.contentWidth(columns: columnCount, isFullscreen: false)))
        )
        .glassPanel(cornerRadius: SwitcherMetrics.panelCornerRadius)
        .shadow(color: Color.black.opacity(isFullscreen ? 0 : 0.42), radius: isFullscreen ? 0 : 30, x: 0, y: 15)
    }

    @ViewBuilder
    private func dimmingLayer(opacity: Double, onTap: @escaping () -> Void) -> some View {
        Color.black.opacity(opacity)
            .ignoresSafeArea()
            .transition(.opacity)
            .onTapGesture(perform: onTap)
    }

    @ViewBuilder
    private var backdrop: some View {
        Color.black.opacity(0.20)
            .ignoresSafeArea()
            .onTapGesture { handleBackdropTap() }
    }

    private func handleBackdropTap() {
        if viewModel.pendingConfirmation != nil {
            viewModel.pendingConfirmation = nil
        } else if viewModel.isHelpOpen {
            viewModel.closeHelp()
        } else if viewModel.isPreviewOpen {
            viewModel.closePreview()
        } else if viewModel.isSettingsOpen {
            viewModel.closeSettings()
        } else if viewModel.isSearchMode {
            viewModel.exitSearchMode()
        } else {
            onCancel()
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Image(systemName: "macwindow.on.rectangle")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accent)

                Text("MonoTab")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                if viewModel.isAppOnlyMode {
                    TagBadge(text: "App Only", tint: accent, size: 10)
                }

                if preferences.useRecentOrdering {
                    TagBadge(icon: "clock.arrow.circlepath", text: "Recent", tint: .secondary, size: 9)
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
                        .foregroundStyle(.secondary)

                    if !viewModel.isSearchMode {
                        headerButton(help: "Search windows (f or /)", action: { viewModel.enterSearchMode() }) {
                            HStack(spacing: 5) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Search")
                                    .font(.system(size: 11, weight: .medium))
                                KeyCap("f", size: 9)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                    }

                    headerButton(
                        help: isFullscreen ? "Switch to floating mode" : "Expand to fullscreen",
                        action: { preferences.toggleDisplayMode() }
                    ) {
                        Image(systemName: isFullscreen
                            ? "arrow.down.right.and.arrow.up.left"
                            : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(6)
                    }

                    headerButton(help: "Keyboard shortcuts (?)", action: { viewModel.toggleHelp() }) {
                        Image(systemName: "questionmark")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(6)
                    }

                    headerButton(help: "Preferences", action: { viewModel.toggleSettings() }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(6)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func headerButton<Label: View>(
        help: String,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            label()
                .glassBadge()
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct WindowGrid: View {
    let viewModel: SwitcherViewModel
    let columnCount: Int
    let cardSize: CGSize
    let onConfirm: () -> Void

    @Environment(\.monoReduceMotion) private var reduceMotion

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(
                .flexible(minimum: cardSize.width - 8, maximum: cardSize.width + 30),
                spacing: SwitcherMetrics.columnSpacing
            ),
            count: columnCount
        )
    }

    var body: some View {
        let windows = viewModel.filteredWindows
        let selectedID = viewModel.selectedWindow?.id
        let quickNumbers = viewModel.quickNumbers()

        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    if windows.isEmpty {
                        EmptyState()
                    } else {
                        LazyVGrid(columns: columns, spacing: SwitcherMetrics.rowSpacing) {
                            ForEach(windows) { window in
                                WindowThumbnailCard(
                                    window: window,
                                    slot: viewModel.slot(for: window.id),
                                    isSelected: window.id == selectedID,
                                    quickNumber: quickNumbers[window.id],
                                    cardSize: cardSize,
                                    onSelect: { viewModel.select(id: window.id) },
                                    onActivate: onConfirm,
                                    onClose: { SwitcherPanelController.shared.close(window: window) }
                                )
                                .equatable()
                                .id(window.id)
                            }
                        }
                        .padding(.horizontal, SwitcherMetrics.gridHorizontalPadding)
                        .padding(.vertical, SwitcherMetrics.gridVerticalPadding)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: viewModel.maxGridHeight)
            .fixedSize(horizontal: false, vertical: true)
            .onChange(of: selectedID) { _, newID in
                guard let newID else { return }
                if reduceMotion {
                    proxy.scrollTo(newID)
                } else {
                    withAnimation(.smooth(duration: 0.15)) { proxy.scrollTo(newID) }
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
                .foregroundStyle(.secondary.opacity(0.5))
            Text("No windows found")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Text("Press Esc to clear the search or dismiss MonoTab")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary.opacity(0.7))
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
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(window.appName)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)

                        if window.isMinimized {
                            TagBadge(icon: "arrow.down.right.and.arrow.up.left", text: "minimized", tint: .orange)
                        }

                        if let display = window.displayIndex {
                            TagBadge(icon: "display", text: "Display \(display)", tint: .blue)
                        }
                    }
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close preview (Space / Esc)")
                .accessibilityLabel("Close preview")
            }

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.08))

                if let image = slot.image {
                    Image(decorative: image, scale: 1, orientation: .up)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(6)
                } else {
                    AppGlyph(pid: window.pid, appName: window.appName, iconSize: 64, showsName: true)
                }
            }
            .frame(minWidth: 480, maxWidth: 820, minHeight: 320, maxHeight: 500)

            HStack {
                HStack(spacing: 10) {
                    ShortcutHint(key: "Space", description: "Close Preview")
                    ShortcutHint(key: "⏎", description: "Switch")
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
        .frame(width: SwitcherMetrics.previewSize.width)
        .glassPanel(cornerRadius: 20)
        .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 12)
    }
}

private struct ShortcutLegend: View {
    let isFullscreen: Bool

    var body: some View {
        HStack(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    ForEach(ShortcutCatalog.legend) { ShortcutHint($0) }
                }

                HStack(spacing: 8) {
                    ForEach(ShortcutCatalog.legend.prefix(4)) { ShortcutHint($0) }
                }

                HStack(spacing: 8) {
                    ShortcutHint(key: "?", description: "Shortcuts")
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Image(systemName: isFullscreen
                    ? "arrow.down.right.and.arrow.up.left"
                    : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 8, weight: .bold))
                Text(isFullscreen ? "Fullscreen" : "Floating")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .surfaceTile(cornerRadius: 4)

            Text("v\(AppInfo.bundleVersion)")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary.opacity(0.7))
        }
    }
}
