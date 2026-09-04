import SwiftUI

public struct SwitcherView: View {
    @ObservedObject var viewModel: SwitcherViewModel
    @ObservedObject var preferences = PreferencesManager.shared
    let onConfirm: () -> Void
    let onCancel: () -> Void

    public init(
        viewModel: SwitcherViewModel,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    private var isFullscreen: Bool {
        preferences.displayMode == .fullscreen
    }

    private var cardWidth: CGFloat {
        isFullscreen ? 278 : 264
    }

    private var cardHeight: CGFloat {
        isFullscreen ? 172 : 162
    }

    private var columns: [GridItem] {
        let colCount = viewModel.columnCount(isFullscreen: isFullscreen)
        return Array(repeating: GridItem(.flexible(minimum: cardWidth - 8, maximum: cardWidth + 30), spacing: 16), count: colCount)
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(isFullscreen ? 0.20 : 0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    if viewModel.isSettingsOpen {
                        withAnimation {
                            viewModel.closeSettings()
                            onCancel()
                        }
                    } else if viewModel.isSearchMode {
                        viewModel.exitSearchMode()
                    } else {
                        onCancel()
                    }
                }

            VStack(spacing: 12) {
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

                    HStack(spacing: 8) {
                        let winCount = viewModel.filteredWindows.count
                        Text("\(winCount) \(winCount == 1 ? "window" : "windows")")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .liquidGlassBadge()
                            .foregroundColor(.secondary)

                        if !viewModel.isSearchMode {
                            Button(action: {
                                withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
                                    viewModel.enterSearchMode()
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("Search")
                                        .font(.system(size: 11, weight: .medium))
                                    Text("f")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1.5)
                                        .background(Color.white.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .liquidGlassBadge()
                                .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Search windows (Press 'f' or '/')")
                        }

                        Button(action: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                preferences.toggleDisplayMode()
                            }
                        }) {
                            Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(6)
                                .liquidGlassBadge()
                        }
                        .buttonStyle(.plain)
                        .help(isFullscreen ? "Switch to floating mode" : "Expand to fullscreen")

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                viewModel.toggleSettings()
                            }
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(6)
                                .liquidGlassBadge()
                        }
                        .buttonStyle(.plain)
                        .help("Preferences")
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)

                if viewModel.isSearchMode {
                    SearchBarView(
                        text: $viewModel.searchQuery,
                        isSearchMode: $viewModel.isSearchMode,
                        onExit: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                viewModel.exitSearchMode()
                            }
                        }
                    )
                    .padding(.horizontal, 18)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                PermissionsBannerView()
                    .padding(.horizontal, 18)

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)

                            if viewModel.filteredWindows.isEmpty {
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
                            } else {
                                LazyVGrid(columns: columns, spacing: 14) {
                                    ForEach(Array(viewModel.filteredWindows.enumerated()), id: \.element.id) { index, window in
                                        WindowThumbnailCard(
                                            window: window,
                                            thumbnail: viewModel.thumbnails[window.id],
                                            isSelected: viewModel.selectedIndex == index,
                                            cardWidth: cardWidth,
                                            cardHeight: cardHeight,
                                            onSelect: {
                                                viewModel.selectedIndex = index
                                            },
                                            onActivate: {
                                                onConfirm()
                                            },
                                            onClose: {
                                                WindowManager.shared.close(window: window)
                                                viewModel.removeWindow(id: window.id)
                                            }
                                        )
                                        .id(window.id)
                                    }
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                            }

                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: isFullscreen ? 520 : 340)
                    }
                    .frame(maxHeight: isFullscreen ? 820 : 640)
                    .onChange(of: viewModel.selectedIndex) { _, newIndex in
                        let list = viewModel.filteredWindows
                        if newIndex >= 0 && newIndex < list.count {
                            withAnimation(.easeInOut(duration: 0.14)) {
                                proxy.scrollTo(list[newIndex].id, anchor: .center)
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    let shortcutLabel = preferences.shortcut == .commandTab ? "⌘ ⇥" : (preferences.shortcut == .both ? "⌥ / ⌘ ⇥" : "⌥ ⇥")
                    ShortcutHint(key: shortcutLabel, description: "Next")
                    ShortcutHint(key: "⇧ + ⇥", description: "Back")
                    ShortcutHint(key: "↑ ↓ ← → / hjkl", description: "Navigate")
                    ShortcutHint(key: "w", description: "Close")
                    ShortcutHint(key: "f or /", description: "Search")
                    ShortcutHint(key: "⏎", description: "Select")
                    ShortcutHint(key: "⎋", description: "Dismiss")

                    Spacer()

                    Text(isFullscreen ? "Fullscreen Mode" : "Floating Mode")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
                .padding(.top, 2)
            }
            .frame(
                minWidth: isFullscreen ? 1080 : 860,
                maxWidth: isFullscreen
                    ? min(2050, max(1080, CGFloat(columns.count) * (cardWidth + 24) + 100))
                    : min(1600, max(860, CGFloat(columns.count) * (cardWidth + 20) + 80)),
                alignment: .center
            )
            .liquidGlassPanel(cornerRadius: 24)
            .shadow(color: Color.black.opacity(0.42), radius: 30, x: 0, y: 15)

            if viewModel.isSettingsOpen {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation {
                            viewModel.closeSettings()
                            onCancel()
                        }
                    }

                SettingsView(onClose: {
                    withAnimation {
                        viewModel.closeSettings()
                        onCancel()
                    }
                })
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isFullscreen)
        .animation(.spring(response: 0.24, dampingFraction: 0.8), value: viewModel.isSearchMode)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isSettingsOpen)
    }
}

struct ShortcutHint: View {
    let key: String
    let description: String

    var body: some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
                )
                .foregroundColor(.primary)

            Text(description)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.secondary)
        }
    }
}
