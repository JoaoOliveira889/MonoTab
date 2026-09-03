import AppKit
import Foundation

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, HotkeyManagerDelegate {
    private var permissionPollTask: Task<Void, Never>?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        PermissionsManager.shared.refresh()

        if !PermissionsManager.shared.hasAccessibility {
            PermissionsManager.shared.checkAccessibility(prompt: true)
        }

        HotkeyManager.shared.delegate = self
        let success = HotkeyManager.shared.start()

        _ = SwitcherPanelController.shared

        if !success {
            startPermissionPolling()
        }
    }

    private func startPermissionPolling() {
        permissionPollTask?.cancel()
        permissionPollTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { break }

                if PermissionsManager.shared.checkAccessibility(prompt: false) {
                    if HotkeyManager.shared.start() {
                        break
                    }
                }
            }
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        permissionPollTask?.cancel()
        permissionPollTask = nil
        HotkeyManager.shared.stop()
        WindowManager.shared.clearCache()
    }

    public func hotkeyDidTriggerOpen() {
        SwitcherPanelController.shared.show()
    }

    public func hotkeyDidCycleNext() {
        if !SwitcherPanelController.shared.isVisible {
            SwitcherPanelController.shared.show()
        } else {
            SwitcherPanelController.shared.viewModel.selectNext()
        }
    }

    public func hotkeyDidCyclePrevious() {
        if !SwitcherPanelController.shared.isVisible {
            SwitcherPanelController.shared.show()
        } else {
            SwitcherPanelController.shared.viewModel.selectPrevious()
        }
    }

    public func hotkeyDidReleaseModifier() {
        SwitcherPanelController.shared.confirmSelection()
    }

    public func hotkeyDidConfirm() {
        SwitcherPanelController.shared.confirmSelection()
    }

    public func hotkeyDidCancel() {
        SwitcherPanelController.shared.handleEscape()
    }

    public func hotkeyDidNavigate(direction: HotkeyManager.NavigationDirection) {
        let count = SwitcherPanelController.shared.viewModel.filteredWindows.count
        let cols = count <= 4 ? max(1, count) : 4
        SwitcherPanelController.shared.viewModel.navigate(direction: direction, columns: cols)
    }

    public func hotkeyDidEnterSearchMode() {
        SwitcherPanelController.shared.enterSearchMode()
    }
}
