import SwiftUI

public struct SettingsView: View {
    @ObservedObject var preferences = PreferencesManager.shared
    @ObservedObject var permissions = PermissionsManager.shared
    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 15, weight: .bold))

                    Text("Preferences")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close preferences (Esc)")
            }

            Divider()
                .opacity(0.25)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    // Section 1: General
                    SettingsSection(title: "General") {
                        // Launch at Login
                        SettingsRow(
                            icon: "arrow.clockwise.circle.fill",
                            iconColor: .blue,
                            title: "Launch at Login",
                            subtitle: "Automatically open MonoTab when starting your Mac."
                        ) {
                            Toggle("", isOn: $preferences.launchAtLogin)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }

                        Divider().opacity(0.15)

                        // Global Activation Shortcut
                        SettingsRow(
                            icon: "keyboard.fill",
                            iconColor: .purple,
                            title: "Activation Shortcut",
                            subtitle: preferences.shortcut.hint
                        ) {
                            Picker("", selection: $preferences.shortcut) {
                                ForEach(ShortcutPreference.allCases) { item in
                                    Text(item.shortName).tag(item)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 210)
                        }

                        Divider().opacity(0.15)

                        // Display Mode
                        SettingsRow(
                            icon: "macwindow.on.rectangle",
                            iconColor: .indigo,
                            title: "Display Mode",
                            subtitle: preferences.displayMode == .compact
                                ? "Centered floating HUD with Liquid Glass blur."
                                : "Immersive expanded grid occupying the display."
                        ) {
                            Picker("", selection: $preferences.displayMode) {
                                ForEach(DisplayModePreference.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 190)
                        }
                    }

                    // Section 2: Windows & Spaces
                    SettingsSection(title: "Windows & Spaces") {
                        // Workspaces / Spaces
                        SettingsRow(
                            icon: "square.grid.2x2.fill",
                            iconColor: .teal,
                            title: "Workspaces",
                            subtitle: preferences.currentSpaceOnly
                                ? "Only showing windows on current desktop space."
                                : "Showing windows across all virtual desktops."
                        ) {
                            Picker("", selection: $preferences.currentSpaceOnly) {
                                Text("Current Space").tag(true)
                                Text("All Spaces").tag(false)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 190)
                        }

                        Divider().opacity(0.15)

                        // Window Visibility
                        SettingsRow(
                            icon: "macwindow.badge.plus",
                            iconColor: .orange,
                            title: "Include Minimized",
                            subtitle: "Show windows minimized to the macOS Dock."
                        ) {
                            Toggle("", isOn: $preferences.showMinimizedWindows)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }

                        Divider().opacity(0.15)

                        // Tab Visibility
                        SettingsRow(
                            icon: "rectangle.split.2x1.fill",
                            iconColor: .cyan,
                            title: "Group Browser Tabs",
                            subtitle: preferences.showAppTabs
                                ? "Showing tabs as individual cards."
                                : "Keeping tabs grouped into their parent window."
                        ) {
                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { !preferences.showAppTabs },
                                    set: { preferences.showAppTabs = !$0 }
                                )
                            )
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                    }

                    // Section 3: Permissions
                    SettingsSection(title: "System Permissions") {
                        HStack(spacing: 12) {
                            PermissionStatusCard(
                                title: "Accessibility",
                                description: "Global hotkeys & window control",
                                isGranted: permissions.hasAccessibility,
                                action: {
                                    permissions.checkAccessibility(prompt: true)
                                    permissions.openAccessibilitySettings()
                                }
                            )

                            PermissionStatusCard(
                                title: "Screen Recording",
                                description: "Window preview thumbnails",
                                isGranted: permissions.hasScreenRecording,
                                action: {
                                    permissions.checkScreenRecording(prompt: true)
                                    permissions.openScreenRecordingSettings()
                                }
                            )
                        }
                    }
                }
            }

            Divider()
                .opacity(0.20)

            // Footer: Privacy & Done Button
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 13))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("100% Local & Private")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Zero telemetry. Thumbnails kept only in RAM.")
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.green.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.green.opacity(0.25), lineWidth: 0.75)
                )

                Spacer()

                Button("Done", action: onClose)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 600, height: 530)
        .liquidGlassPanel(cornerRadius: 20)
    }
}

// MARK: - Subcomponents

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.secondary.opacity(0.85))
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.75)
            )
        }
    }
}

private struct SettingsRow<Control: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            control()
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
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)

                if !isGranted {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }
}
