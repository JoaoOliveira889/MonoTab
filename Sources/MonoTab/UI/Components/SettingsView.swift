import SwiftUI

public struct SettingsView: View {
    @ObservedObject var preferences = PreferencesManager.shared
    @ObservedObject var permissions = PermissionsManager.shared
    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close preferences (Esc)")
            }

            Divider()
                .opacity(0.25)

            // Global Activation Shortcut
            VStack(alignment: .leading, spacing: 6) {
                Label("Global Activation Shortcut", systemImage: "keyboard")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)

                Picker("", selection: $preferences.shortcut) {
                    ForEach(ShortcutPreference.allCases) { item in
                        Text(item.displayName).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                Text(preferences.shortcut.hint)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
            }

            // Display Mode
            VStack(alignment: .leading, spacing: 6) {
                Label("Display Mode", systemImage: "macwindow.on.rectangle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)

                Picker("", selection: $preferences.displayMode) {
                    ForEach(DisplayModePreference.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(preferences.displayMode == .compact
                    ? "Centered, spacious floating panel with Liquid Glass blur."
                    : "Immersive expanded grid occupying the active display.")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
            }

            // Window Visibility (Minimized Windows Option)
            VStack(alignment: .leading, spacing: 6) {
                Label("Window Visibility", systemImage: "macwindow.badge.plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)

                Picker("", selection: $preferences.showMinimizedWindows) {
                    Text("Active Only").tag(false)
                    Text("Show All (Include Minimized)").tag(true)
                }
                .pickerStyle(.segmented)

                Text(preferences.showMinimizedWindows
                    ? "Showing all application windows, including those minimized to the Dock."
                    : "Only showing windows currently active on screen.")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
            }

            // Permissions
            VStack(alignment: .leading, spacing: 6) {
                Label("Permissions Status", systemImage: "lock.shield")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)

                HStack(spacing: 10) {
                    PermissionStatusBadge(
                        title: "Accessibility",
                        isGranted: permissions.hasAccessibility,
                        action: {
                            permissions.checkAccessibility(prompt: true)
                            permissions.openAccessibilitySettings()
                        }
                    )

                    PermissionStatusBadge(
                        title: "Screen Recording",
                        isGranted: permissions.hasScreenRecording,
                        action: {
                            permissions.checkScreenRecording(prompt: true)
                            permissions.openScreenRecordingSettings()
                        }
                    )
                }
            }

            // Privacy & Security Guarantee Banner
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 2) {
                    Text("100% Local & Private")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Zero telemetry, zero data collection. Thumbnails are kept only in RAM.")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.green.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.green.opacity(0.25), lineWidth: 0.75)
            )

            Spacer(minLength: 0)

            // Done Button
            HStack {
                Spacer()
                Button("Done", action: onClose)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 500, height: 470)
        .liquidGlassPanel(cornerRadius: 20)
    }
}

struct PermissionStatusBadge: View {
    let title: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isGranted ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)

                if !isGranted {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }
}
