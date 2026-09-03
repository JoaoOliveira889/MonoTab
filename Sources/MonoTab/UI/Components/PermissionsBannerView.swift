import SwiftUI

public struct PermissionsBannerView: View {
    @ObservedObject var permissions = PermissionsManager.shared

    public init() {}

    public var body: some View {
        if !permissions.allGranted && !permissions.bannerDismissed {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 14))

                    Text("Required permissions for full functionality:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    Button(action: {
                        withAnimation {
                            permissions.dismissBanner()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss warning")
                }

                HStack(spacing: 12) {
                    if !permissions.hasAccessibility {
                        Button(action: {
                            permissions.checkAccessibility(prompt: true)
                            permissions.openAccessibilitySettings()
                        }) {
                            Label("Enable Accessibility", systemImage: "hand.tap.fill")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)
                    }

                    if !permissions.hasScreenRecording {
                        Button(action: {
                            permissions.checkScreenRecording(prompt: true)
                            permissions.openScreenRecordingSettings()
                        }) {
                            Label("Enable Screen Recording", systemImage: "record.circle")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .controlSize(.small)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.orange.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }
}
