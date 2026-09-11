import SwiftUI

struct PendingConfirmation: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let confirmTitle: String
    let icon: String
    let perform: @MainActor () -> Void
}

struct ConfirmationOverlayView: View {
    let confirmation: PendingConfirmation
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: confirmation.icon)
                .font(.system(size: 26, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.orange)

            VStack(spacing: 5) {
                Text(confirmation.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(confirmation.message)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            HStack(spacing: 10) {
                Button("Cancel", action: onCancel)
                    .controlSize(.regular)
                    .keyboardShortcut(.cancelAction)

                Button(confirmation.confirmTitle, action: onConfirm)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.regular)
                    .keyboardShortcut(.defaultAction)
            }

            HStack(spacing: 10) {
                ShortcutHint(key: "⏎", description: "Confirm")
                ShortcutHint(key: "⎋", description: "Cancel")
            }
        }
        .padding(22)
        .frame(width: 340)
        .glassPanel(cornerRadius: 18)
        .shadow(color: Color.black.opacity(0.4), radius: 22, x: 0, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(confirmation.title). \(confirmation.message)")
    }
}
