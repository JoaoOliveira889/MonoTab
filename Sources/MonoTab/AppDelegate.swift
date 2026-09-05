import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, HotkeyManagerDelegate {
    private var permissionPollTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let permissions = PermissionsManager.shared
        permissions.refresh(force: true)
        if !permissions.hasAccessibility {
            permissions.requestAccessibility()
        }

        HotkeyManager.shared.delegate = self
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
        HotkeyManager.shared.stop()
        SwitcherPanelController.shared.viewModel.cancelPendingWork()
        WindowManager.shared.clearCache()
        AppIconCache.clear()
    }

    private func startPermissionPolling() {
        permissionPollTask?.cancel()
        permissionPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }

                PermissionsManager.shared.refresh(force: true)
                guard PermissionsManager.shared.hasAccessibility, HotkeyManager.shared.start() else { continue }

                self?.permissionPollTask = nil
                return
            }
        }
    }

    func hotkeyDidTriggerOpen() {
        SwitcherPanelController.shared.show()
    }

    func hotkeyDidCycleNext() {
        let controller = SwitcherPanelController.shared
        if controller.isVisible {
            controller.viewModel.selectNext()
        } else {
            controller.show()
        }
    }

    func hotkeyDidCyclePrevious() {
        let controller = SwitcherPanelController.shared
        if controller.isVisible {
            controller.viewModel.selectPrevious()
        } else {
            controller.show()
        }
    }

    func hotkeyDidConfirm() {
        SwitcherPanelController.shared.confirmSelection()
    }

    func hotkeyDidCancel() {
        SwitcherPanelController.shared.handleEscape()
    }

    func hotkeyDidNavigate(direction: HotkeyManager.NavigationDirection) {
        let viewModel = SwitcherPanelController.shared.viewModel
        let isFullscreen = PreferencesManager.shared.displayMode == .fullscreen
        viewModel.navigate(direction: direction, columns: viewModel.columnCount(isFullscreen: isFullscreen))
    }

    func hotkeyDidEnterSearchMode() {
        SwitcherPanelController.shared.enterSearchMode()
    }

    func hotkeyDidCloseSelectedWindow() {
        SwitcherPanelController.shared.closeSelectedWindow()
    }

    func hotkeyDidQuitSelectedApp() {
        SwitcherPanelController.shared.quitSelectedApp()
    }
}
