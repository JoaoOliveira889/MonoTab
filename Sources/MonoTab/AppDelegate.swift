import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let initialPollInterval = Duration.seconds(1.5)
    private static let maximumPollInterval = Duration.seconds(15)

    private var permissionPollTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let permissions = PermissionsManager.shared
        permissions.refresh(force: true)
        if !permissions.hasAccessibility {
            permissions.request(.accessibility)
        }

        WindowActivationHistory.shared.startObservingApplicationActivation()

        HotkeyManager.shared.delegate = SwitcherPanelController.shared
        HotkeyManager.shared.setShortcutPreference(PreferencesManager.shared.shortcut)

        _ = SwitcherPanelController.shared
        StatusItemController.shared.setVisible(PreferencesManager.shared.showMenuBarIcon)

        if !HotkeyManager.shared.start() {
            startPermissionPolling()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionPollTask?.cancel()
        permissionPollTask = nil
        PermissionsManager.shared.stopPolling()
        HotkeyManager.shared.stop()
        SwitcherPanelController.shared.viewModel.cancelPendingWork()
        WindowManager.shared.clearCache()
        AppIconCache.clear()
    }

    private func startPermissionPolling() {
        permissionPollTask?.cancel()
        permissionPollTask = Task { [weak self] in
            var interval = Self.initialPollInterval

            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }

                PermissionsManager.shared.refresh(force: true)
                if PermissionsManager.shared.hasAccessibility, HotkeyManager.shared.start() {
                    self?.permissionPollTask = nil
                    return
                }

                interval = min(interval * 2, Self.maximumPollInterval)
            }
        }
    }
}
