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

final class SwitcherPanelController: NSObject, NSWindowDelegate, HotkeyManagerDelegate {
    static let shared = SwitcherPanelController()

    let panel: SwitcherPanel
    let viewModel: SwitcherViewModel

    private let hostingView: NSHostingView<SwitcherView>
    private var outsideClickMonitor: Any?
    private var presentationGeneration = 0

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

    // MARK: - Presentation

    func show(appOnly: Bool = false) {
        presentationGeneration += 1

        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        viewModel.refreshWindows(appOnly: appOnly, targetPID: frontPID, screens: ScreenSnapshot.capture())
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
        presentationGeneration += 1
        let generation = presentationGeneration

        stopOutsideClickMonitor()
        PermissionsManager.shared.stopPolling()
        viewModel.cancelPendingWork()
        viewModel.pendingConfirmation = nil
        viewModel.closeSettings()
        viewModel.closeHelp()
        viewModel.exitSearchMode()
        viewModel.closePreview()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.10
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.presentationGeneration == generation else { return }
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1.0
                self.syncOverlayState()
            }
        })
    }

    func showPreferences() {
        if !panel.isVisible { show(appOnly: false) }
        viewModel.openSettings()
    }

    func syncOverlayState() {
        HotkeyManager.shared.updateOverlayState(
            isVisible: panel.isVisible,
            isTextEntryActive: viewModel.isTextEntryActive
        )
        if panel.isVisible, viewModel.isSettingsOpen {
            PermissionsManager.shared.startPolling()
        } else {
            PermissionsManager.shared.stopPolling()
        }
    }

    // MARK: - Hotkey routing

    func perform(_ action: HotkeyAction) {
        if viewModel.pendingConfirmation != nil {
            switch action {
            case .confirm: resolveConfirmation()
            case .cancel: viewModel.pendingConfirmation = nil
            default: break
            }
            return
        }

        switch action {
        case let .open(appOnly):
            show(appOnly: appOnly)
        case let .cycle(forward):
            if panel.isVisible {
                viewModel.cycle(forward: forward)
            } else {
                show(appOnly: false)
            }
        case .confirm:
            if viewModel.isHelpOpen {
                viewModel.closeHelp()
            } else {
                confirmSelection()
            }
        case .cancel:
            handleEscape()
        case let .navigate(direction):
            let isFullscreen = PreferencesManager.shared.displayMode == .fullscreen
            viewModel.navigate(direction: direction, columns: viewModel.columnCount(isFullscreen: isFullscreen))
        case .enterSearch:
            viewModel.enterSearchMode()
        case .toggleHelp:
            viewModel.toggleHelp()
        case .togglePreview:
            guard viewModel.isPreviewOpen || viewModel.selectedWindow != nil else { return }
            viewModel.togglePreview()
        case .closeWindow:
            closeSelectedWindow()
        case .quitApp:
            quitSelectedApp()
        case .hideApp:
            hideSelectedApp()
        case .toggleMinimize:
            withSelectedWindow { WindowManager.shared.toggleMinimize(window: $0) }
        case .toggleZoom:
            withSelectedWindow { WindowManager.shared.toggleZoom(window: $0) }
        case let .tile(side):
            withSelectedWindow { WindowManager.shared.tile(window: $0, side: side, screens: ScreenSnapshot.capture()) }
        case .moveToNextDisplay:
            withSelectedWindow {
                WindowManager.shared.moveToNextDisplay(window: $0, screens: ScreenSnapshot.capture())
            }
        case let .quickSelect(number):
            quickSelect(number: number)
        }
    }

    private func withSelectedWindow(_ body: (WindowInfo) -> Void) {
        guard let window = viewModel.selectedWindow else { return }
        body(window)
    }

    func handleEscape() {
        if viewModel.pendingConfirmation != nil {
            viewModel.pendingConfirmation = nil
        } else if viewModel.isHelpOpen {
            viewModel.closeHelp()
        } else if viewModel.isPreviewOpen {
            viewModel.closePreview()
        } else if viewModel.isSettingsOpen {
            viewModel.closeSettings()
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
            WindowActivationHistory.shared.record(window: target)
            WindowManager.shared.focus(window: target)
        }
    }

    func quickSelect(number: Int) {
        if viewModel.quickSelect(number: number) != nil {
            confirmSelection()
        }
    }

    func hideSelectedApp() {
        withSelectedWindow { WindowManager.shared.hideApplication(pid: $0.pid) }
    }

    // MARK: - Destructive actions

    private func resolveConfirmation() {
        guard let confirmation = viewModel.pendingConfirmation else { return }
        viewModel.pendingConfirmation = nil
        confirmation.perform()
    }

    func confirm(_ confirmation: PendingConfirmation) {
        guard PreferencesManager.shared.confirmDestructiveActions else {
            confirmation.perform()
            return
        }
        viewModel.pendingConfirmation = confirmation
    }

    func close(window: WindowInfo) {
        confirm(
            PendingConfirmation(
                title: "Close window?",
                message: "\(window.appName) — \(window.displayTitle)",
                confirmTitle: "Close",
                icon: "xmark.circle.fill"
            ) {
                WindowManager.shared.close(window: window)
                WindowActivationHistory.shared.forget(windowID: window.id)
                SwitcherPanelController.shared.viewModel.removeWindow(id: window.id)
            }
        )
    }

    func closeSelectedWindow() {
        withSelectedWindow { close(window: $0) }
    }

    func quitSelectedApp() {
        withSelectedWindow { window in
            confirm(
                PendingConfirmation(
                    title: "Quit \(window.appName)?",
                    message: "Every window of this app will be closed.",
                    confirmTitle: "Quit",
                    icon: "power.circle.fill"
                ) {
                    WindowManager.shared.quitApplication(pid: window.pid)
                    WindowActivationHistory.shared.forget(pid: window.pid)
                    SwitcherPanelController.shared.viewModel.removeWindows(pid: window.pid)
                }
            )
        }
    }

    // MARK: - Layout

    func layoutPanel(animated: Bool = true) {
        guard let screen = activeScreen() else { return }
        let visible = screen.visibleFrame
        viewModel.maxGridHeight = max(240, visible.height - SwitcherMetrics.reservedVerticalChrome)

        let isFullscreen = PreferencesManager.shared.displayMode == .fullscreen
        let target: NSRect

        if isFullscreen {
            target = visible
        } else {
            target = centered(size: floatingSize(in: visible), in: visible)
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

    private func floatingSize(in visible: NSRect) -> NSSize {
        let padding: CGFloat = 40

        if let sheet = viewModel.activeSheet {
            let size: CGSize
            switch sheet {
            case .settings: size = SwitcherMetrics.settingsSize
            case .help: size = SwitcherMetrics.helpSize
            case .preview: size = SwitcherMetrics.previewSize
            }
            return NSSize(
                width: min(visible.width - padding, size.width + padding),
                height: min(visible.height - padding, size.height + padding)
            )
        }

        let columnCount = viewModel.columnCount(isFullscreen: false)
        let contentWidth = SwitcherMetrics.contentWidth(columns: columnCount, isFullscreen: false)
        let width = min(visible.width - SwitcherMetrics.screenMargin, max(SwitcherMetrics.minPanelWidth, contentWidth))

        let rows = SwitcherMetrics.rowCount(items: viewModel.filteredWindows.count, columns: columnCount)
        let gridHeight = SwitcherMetrics.gridHeight(rows: rows, isFullscreen: false)
        let chrome = viewModel.isSearchMode ? SwitcherMetrics.chromeSearching : SwitcherMetrics.chromeIdle
        let contentHeight = min(viewModel.maxGridHeight + chrome, gridHeight + chrome)
        let height = min(visible.height - SwitcherMetrics.screenMargin, max(SwitcherMetrics.minPanelHeight, contentHeight))

        return NSSize(width: width, height: height)
    }

    private func centered(size: NSSize, in visible: NSRect) -> NSRect {
        NSRect(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2,
            width: size.width,
            height: size.height
        ).integral
    }

    private func activeScreen() -> NSScreen? {
        if PreferencesManager.shared.screenTarget == .activeWindow,
           let frontmostApp = NSWorkspace.shared.frontmostApplication,
           let window = viewModel.windows.first(where: { $0.pid == frontmostApp.processIdentifier }) {
            let snapshot = ScreenSnapshot.capture()
            if let index = snapshot.screenIndex(containingCoreGraphics: window.bounds),
               NSScreen.screens.indices.contains(index) {
                return NSScreen.screens[index]
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
