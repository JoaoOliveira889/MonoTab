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
final class SwitcherPanelController: NSObject, NSWindowDelegate {
    static let shared = SwitcherPanelController()

    let panel: SwitcherPanel
    let viewModel: SwitcherViewModel

    private let hostingView: NSHostingView<SwitcherView>
    private var outsideClickMonitor: Any?

    private override init() {
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
        super.init()

        panel.delegate = self

        viewModel.onOverlayStateChange = { [weak self] in
            guard let self, panel.isVisible else { return }
            syncOverlayState()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        hostingView.layoutSubtreeIfNeeded()
    }

    @objc private func screenParametersDidChange() {
        if panel.isVisible {
            layoutPanel()
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        if panel.isVisible {
            hide()
        }
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func show(appOnly: Bool = false) {
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        viewModel.refreshWindows(appOnly: appOnly, targetPID: frontPID)
        layoutPanel(animated: false)

        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        startOutsideClickMonitor()
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1.0
        }

        syncOverlayState()
        PermissionsManager.shared.refresh()
    }

    func hide() {
        stopOutsideClickMonitor()
        viewModel.cancelPendingWork()
        viewModel.closeSettings()
        viewModel.exitSearchMode()
        viewModel.closePreview()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.10
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1.0
                self.syncOverlayState()
            }
        })
    }

    func enterSearchMode() {
        viewModel.enterSearchMode()
    }

    func handleEscape() {
        if viewModel.isPreviewOpen {
            viewModel.closePreview()
        } else if viewModel.isSettingsOpen {
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

    func quickSelect(number: Int) {
        if viewModel.quickSelect(number: number) != nil {
            confirmSelection()
        }
    }

    func toggleMinimizeSelected() {
        viewModel.toggleMinimizeSelected()
    }

    func toggleZoomSelected() {
        viewModel.toggleZoomSelected()
    }

    func hideSelectedApp() {
        viewModel.hideSelectedApp()
    }

    func showPreferences() {
        if !panel.isVisible { show(appOnly: false) }
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

    func layoutPanel(animated: Bool = true) {
        guard let screen = activeScreen() else { return }
        let visible = screen.visibleFrame
        viewModel.maxGridHeight = max(240, visible.height - Self.panelChromeHeight)

        let coversScreen = PreferencesManager.shared.displayMode == .fullscreen || viewModel.isSettingsOpen || viewModel.isPreviewOpen
        let target: NSRect

        if coversScreen {
            target = visible
        } else {
            let columnCount = viewModel.columnCount(isFullscreen: false)
            let cardW: CGFloat = 264
            let cardH: CGFloat = 162
            let spacingH: CGFloat = 16
            let spacingV: CGFloat = 14
            let horizontalPadding: CGFloat = 36
            let contentWidth = CGFloat(columnCount) * cardW + CGFloat(max(0, columnCount - 1)) * spacingH + horizontalPadding + 48
            let finalWidth = min(visible.width - 60, max(700, contentWidth))

            let rowCount = max(1, (viewModel.filteredWindows.count + columnCount - 1) / max(1, columnCount))
            let gridHeight = CGFloat(rowCount) * cardH + CGFloat(max(0, rowCount - 1)) * spacingV + 24
            let chromeHeight: CGFloat = viewModel.isSearchMode ? 175 : 130
            let contentHeight = min(viewModel.maxGridHeight + chromeHeight, gridHeight + chromeHeight)
            let finalHeight = min(visible.height - 60, max(280, contentHeight))

            let size = NSSize(width: finalWidth, height: finalHeight)
            target = NSRect(
                x: visible.midX - size.width / 2,
                y: visible.midY - size.height / 2,
                width: size.width,
                height: size.height
            ).integral
        }

        guard panel.frame != target else { return }

        let shouldAnimate = animated && !panel.frame.isEmpty && panel.isVisible
        if shouldAnimate {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.20
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                context.allowsImplicitAnimation = true
                panel.animator().setFrame(target, display: true)
            }
        } else {
            panel.setFrame(target, display: true)
        }
    }

    private func activeScreen() -> NSScreen? {
        if PreferencesManager.shared.screenTarget == .activeWindow,
           let frontmostApp = NSWorkspace.shared.frontmostApplication,
           let window = viewModel.windows.first(where: { $0.pid == frontmostApp.processIdentifier }) {
            let center = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
            if let screen = NSScreen.screens.first(where: { NSMouseInRect(center, $0.frame, false) }) {
                return screen
            }
        }

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
