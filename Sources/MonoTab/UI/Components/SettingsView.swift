import SwiftUI

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case windows
    case appearance
    case shortcuts
    case permissions
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .windows: "Windows"
        case .appearance: "Appearance"
        case .shortcuts: "Shortcuts"
        case .permissions: "Permissions"
        case .about: "About"
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .windows: "macwindow.on.rectangle"
        case .appearance: "paintpalette"
        case .shortcuts: "keyboard"
        case .permissions: "lock.shield"
        case .about: "info.circle"
        }
    }
}

struct SettingsView: View {
    @Bindable private var preferences = PreferencesManager.shared
    private let permissions = PermissionsManager.shared

    let onClose: () -> Void

    @State private var tab: SettingsTab = .general
    @State private var isConfirmingReset = false
    @Environment(\.monoAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Picker("", selection: $tab) {
                ForEach(SettingsTab.allCases) { item in
                    Label(item.title, systemImage: item.icon).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    switch tab {
                    case .general: generalTab
                    case .windows: windowsTab
                    case .appearance: appearanceTab
                    case .shortcuts: shortcutsTab
                    case .permissions: permissionsTab
                    case .about: aboutTab
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().opacity(0.20)

            footer
        }
        .padding(20)
        .frame(width: SwitcherMetrics.settingsSize.width)
        .frame(maxHeight: SwitcherMetrics.settingsSize.height)
        .glassPanel(cornerRadius: 20)
        .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 12)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(accent)
                    .font(.system(size: 15, weight: .bold))

                Text("Preferences")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("v\(AppInfo.bundleVersion)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .glassBadge()
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close preferences (Esc)")
            .accessibilityLabel("Close preferences")
        }
    }

    private var footer: some View {
        HStack(alignment: .center) {
            if isConfirmingReset {
                HStack(spacing: 8) {
                    Text("Restore every preference to its default?")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)

                    Button("Cancel") { isConfirmingReset = false }
                        .controlSize(.small)

                    Button("Restore") {
                        preferences.restoreDefaults()
                        isConfirmingReset = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
                }
            } else {
                Button("Restore Defaults") { isConfirmingReset = true }
                    .controlSize(.small)
            }

            Spacer()

            Button("Done", action: onClose)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Tabs

    private var generalTab: some View {
        SettingsSection(title: "General") {
            SettingsRow(
                icon: "arrow.clockwise.circle",
                title: "Launch at Login",
                subtitle: "Open MonoTab automatically when the Mac starts."
            ) {
                SettingsToggle(isOn: $preferences.launchAtLogin, label: "Launch at login")
            }

            SettingsDivider()

            SettingsRow(
                icon: "menubar.arrow.up.rectangle",
                title: "Menu Bar Icon",
                subtitle: "The only way to reach preferences or quit while the hotkey is unavailable."
            ) {
                SettingsToggle(isOn: $preferences.showMenuBarIcon, label: "Show menu bar icon")
            }

            SettingsDivider()

            SettingsRow(
                icon: "display.2",
                title: "Active Display",
                subtitle: "Where MonoTab should appear on multi-monitor setups."
            ) {
                Picker("", selection: $preferences.screenTarget) {
                    ForEach(ScreenTargetPreference.allCases) { target in
                        Text(target.displayName).tag(target)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 200)
            }

            SettingsDivider()

            SettingsRow(
                icon: "exclamationmark.shield",
                title: "Confirm Destructive Actions",
                subtitle: "Ask before closing a window or quitting an app."
            ) {
                SettingsToggle(isOn: $preferences.confirmDestructiveActions, label: "Confirm destructive actions")
            }
        }
    }

    private var windowsTab: some View {
        SettingsSection(title: "Windows & Spaces") {
            SettingsRow(
                icon: "clock.arrow.circlepath",
                title: "Most Recently Used Order",
                subtitle: preferences.useRecentOrdering
                    ? "Cards follow the order in which you last used the windows."
                    : "Cards follow the system stacking order."
            ) {
                SettingsToggle(isOn: $preferences.useRecentOrdering, label: "Most recently used order")
            }

            SettingsDivider()

            SettingsRow(
                icon: "square.grid.2x2",
                title: "Workspaces",
                subtitle: preferences.currentSpaceOnly
                    ? "Only windows on the current desktop space."
                    : "Windows across every virtual desktop."
            ) {
                Picker("", selection: $preferences.currentSpaceOnly) {
                    Text("Current Space").tag(true)
                    Text("All Spaces").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)
            }

            SettingsDivider()

            SettingsRow(
                icon: "macwindow.badge.plus",
                title: "Include Minimized",
                subtitle: "Show windows minimized to the macOS Dock."
            ) {
                SettingsToggle(isOn: $preferences.showMinimizedWindows, label: "Include minimized windows")
            }

            SettingsDivider()

            SettingsRow(
                icon: "rectangle.split.2x1",
                title: "Group Browser Tabs",
                subtitle: preferences.groupBrowserTabs
                    ? "Tabs stay grouped inside their parent window."
                    : "Each tab shows up as its own card."
            ) {
                SettingsToggle(isOn: $preferences.groupBrowserTabs, label: "Group browser tabs")
            }
        }
    }

    private var appearanceTab: some View {
        VStack(spacing: 14) {
            SettingsSection(title: "Appearance") {
                SettingsRow(
                    icon: "macwindow.on.rectangle",
                    title: "Display Mode",
                    subtitle: preferences.displayMode == .compact
                        ? "Centered floating panel with Liquid Glass blur."
                        : "Immersive expanded grid filling the display."
                ) {
                    Picker("", selection: $preferences.displayMode) {
                        ForEach(DisplayModePreference.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 190)
                }

                SettingsDivider()

                SettingsRow(
                    icon: "number.circle",
                    title: "Quick Numbers (1-9)",
                    subtitle: "Show jump badges on the first nine window cards."
                ) {
                    SettingsToggle(isOn: $preferences.showQuickShortcuts, label: "Show quick numbers")
                }
            }

            SettingsSection(title: "Accent") {
                AccentPicker(selection: $preferences.accent)
            }
        }
    }

    private var shortcutsTab: some View {
        VStack(spacing: 14) {
            SettingsSection(title: "Activation") {
                SettingsRow(
                    icon: "keyboard",
                    title: "Activation Shortcut",
                    subtitle: preferences.shortcut.hint
                ) {
                    Picker("", selection: $preferences.shortcut) {
                        ForEach(ShortcutPreference.allCases) { item in
                            Text(item.shortName).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 210)
                }
            }

            ForEach(ShortcutCatalog.groups) { group in
                SettingsSection(title: group.title) {
                    ForEach(group.items) { item in
                        ShortcutHint(item)
                    }
                }
            }
        }
    }

    private var permissionsTab: some View {
        SettingsSection(title: "System Permissions") {
            PermissionStatusCard(
                title: "Accessibility",
                description: "Global hotkeys, window activation and window actions.",
                isGranted: permissions.hasAccessibility,
                action: { permissions.openSettings(for: .accessibility) }
            )

            PermissionStatusCard(
                title: "Screen Recording",
                description: "Live window preview thumbnails.",
                isGranted: permissions.hasScreenRecording,
                action: { permissions.openSettings(for: .screenRecording) }
            )

            Text("MonoTab re-checks these while this screen is open.")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.secondary)
        }
    }

    private var aboutTab: some View {
        SettingsSection(title: "About") {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 2) {
                    Text("MonoTab v\(AppInfo.bundleVersion) (Build \(AppInfo.bundleBuild))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("100% local. Zero telemetry, zero network access. Thumbnails live only in RAM.")
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            SettingsDivider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Apple Silicon only. Requires macOS 26 or newer.")
                Text("Not sandboxed: Accessibility and cross-app capture require it.")
            }
            .font(.system(size: 10.5, weight: .regular))
            .foregroundStyle(.secondary)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.85))
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .surfaceTile(cornerRadius: 12)
        }
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider().opacity(0.15)
    }
}

private struct SettingsToggle: View {
    @Binding var isOn: Bool
    let label: String

    var body: some View {
        Toggle(label, isOn: $isOn)
            .toggleStyle(.switch)
            .labelsHidden()
            .accessibilityLabel(label)
    }
}

private struct SettingsRow<Control: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            control()
        }
    }
}

private struct AccentPicker: View {
    @Binding var selection: AccentPreference

    var body: some View {
        HStack(spacing: 10) {
            ForEach(AccentPreference.allCases) { option in
                Button {
                    selection = option
                } label: {
                    VStack(spacing: 5) {
                        Circle()
                            .fill(option.color)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle().strokeBorder(
                                    selection == option ? Color.primary.opacity(0.75) : Color.primary.opacity(0.15),
                                    lineWidth: selection == option ? 2 : 1
                                )
                            )

                        Text(option.displayName)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(selection == option ? .primary : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .help(option.displayName)
                .accessibilityLabel("Accent \(option.displayName)")
                .accessibilityAddTraits(selection == option ? [.isSelected] : [])
            }

            Spacer(minLength: 0)
        }
    }
}

private struct PermissionStatusCard: View {
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(isGranted ? Color.green : Color.orange)
                    .frame(width: 9, height: 9)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text(isGranted ? "Granted" : "Open Settings")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                if !isGranted {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceTile(cornerRadius: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title): \(isGranted ? "granted" : "not granted"). \(description)")
    }
}
