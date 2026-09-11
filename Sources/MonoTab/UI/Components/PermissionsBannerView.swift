import SwiftUI

struct PermissionsBannerView: View {
    private let permissions = PermissionsManager.shared

    var body: some View {
        if !permissions.allGranted && !permissions.bannerDismissed {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.orange)
                        .font(.system(size: 14))

                    Text("Required permissions for full functionality:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Button {
                        permissions.dismissBanner()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss warning")
                    .accessibilityLabel("Dismiss permissions warning")
                }

                HStack(spacing: 12) {
                    if !permissions.hasAccessibility {
                        Button {
                            permissions.openSettings(for: .accessibility)
                        } label: {
                            Label("Enable Accessibility", systemImage: "hand.tap.fill")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)
                    }

                    if !permissions.hasScreenRecording {
                        Button {
                            permissions.openSettings(for: .screenRecording)
                        } label: {
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
                    .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }
}
