import AppKit
import SwiftUI

final class SwitcherPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 520),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .statusBar
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
    }

    override var canBecomeKey: Bool { true }
}

@MainActor
final class SwitcherPanelController {
    static let shared = SwitcherPanelController()

    let panel: SwitcherPanel
    let viewModel: SwitcherViewModel

    private let hostingView: NSHostingView<SwitcherView>
    private var outsideClickMonitor: Any?

    private init() {
        panel = SwitcherPanel()
        let viewModel = SwitcherViewModel()
        self.viewModel = viewModel

        hostingView = NSHostingView(
            rootView: SwitcherView(
                viewModel: viewModel,
                onConfirm: { SwitcherPanelController.shared.confirmSelection() },
                onCancel: { SwitcherPanelController.shared.hide() },
                onLayoutChange: { SwitcherPanelController.shared.layoutPanel() }
            )
        )
        panel.contentView = hostingView

        viewModel.onOverlayStateChange = { [weak self] in
            guard let self, panel.isVisible else { return }
            syncOverlayState()
        }

        hostingView.layoutSubtreeIfNeeded()
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func show() {
        viewModel.refreshWindows()
        layoutPanel()

        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        startOutsideClickMonitor()
        NSApp.activate(ignoringOtherApps: true)

        syncOverlayState()
        PermissionsManager.shared.refresh()
    }

    func hide() {
        stopOutsideClickMonitor()
        viewModel.cancelPendingWork()
        viewModel.closeSettings()
        viewModel.exitSearchMode()
        panel.orderOut(nil)
        syncOverlayState()
    }

    func enterSearchMode() {
        viewModel.enterSearchMode()
    }

    func handleEscape() {
        if viewModel.isSettingsOpen {
            hide()
        } else if viewModel.isSearchMode {
            if viewModel.searchQuery.isEmpty {
                viewModel.exitSearchMode()
            } else {
                viewModel.searchQuery = ""
            }
        } else {
            hide()
        }
    }

    func confirmSelection() {
        let target = viewModel.selectedWindow
        hide()
        if let target {
            WindowManager.shared.focus(window: target)
        }
    }

    func showPreferences() {
        if !panel.isVisible { show() }
        viewModel.openSettings()
    }

    func quitSelectedApp() {
        guard let window = viewModel.selectedWindow else { return }
        WindowManager.shared.quitApplication(pid: window.pid)
        viewModel.removeWindows(pid: window.pid)
    }

    func close(window: WindowInfo) {
        WindowManager.shared.close(window: window)
        viewModel.removeWindow(id: window.id)
    }

    func closeSelectedWindow() {
        guard let window = viewModel.selectedWindow else { return }
        close(window: window)
    }

    func syncOverlayState() {
        HotkeyManager.shared.updateOverlayState(
            isVisible: panel.isVisible,
            isSearchMode: viewModel.isSearchMode,
            isSettingsOpen: viewModel.isSettingsOpen
        )
    }

    private static let panelChromeHeight: CGFloat = 200

    func layoutPanel() {
        guard let screen = activeScreen() else { return }
        let visible = screen.visibleFrame
        viewModel.maxGridHeight = max(240, visible.height - Self.panelChromeHeight)
        hostingView.layoutSubtreeIfNeeded()

        let coversScreen = PreferencesManager.shared.displayMode == .fullscreen || viewModel.isSettingsOpen
        let target: NSRect

        if coversScreen {
            target = visible
        } else {
            let fitting = hostingView.fittingSize
            let size = NSSize(
                width: min(max(fitting.width, 320), visible.width),
                height: min(max(fitting.height, 240), visible.height)
            )
            target = NSRect(
                x: visible.midX - size.width / 2,
                y: visible.midY - size.height / 2,
                width: size.width,
                height: size.height
            ).integral
        }

        guard panel.frame != target else { return }
        panel.setFrame(target, display: false)
    }

    private func activeScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func startOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
    }

    private func stopOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        outsideClickMonitor = nil
    }
}
