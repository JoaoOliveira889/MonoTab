import AppKit
import Combine
import SwiftUI

public final class SwitcherPanel: NSPanel {
    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 520),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .statusBar
        self.isFloatingPanel = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovableByWindowBackground = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        self.hidesOnDeactivate = false
    }

    public override var canBecomeKey: Bool {
        true
    }

    public override var canBecomeMain: Bool {
        true
    }
}

@MainActor
public final class SwitcherPanelController {
    public static let shared = SwitcherPanelController()

    public let panel: SwitcherPanel
    public let viewModel: SwitcherViewModel
    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.panel = SwitcherPanel()
        let vm = SwitcherViewModel()
        self.viewModel = vm

        let rootView = SwitcherView(
            viewModel: vm,
            onConfirm: { [weak self] in
                self?.confirmSelection()
            },
            onCancel: { [weak self] in
                self?.hide()
            }
        )

        let hostingView = NSHostingView(rootView: rootView)
        self.panel.contentView = hostingView

        vm.$searchQuery
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncOverlayState()
            }
            .store(in: &cancellables)

        vm.$isSearchMode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncOverlayState()
            }
            .store(in: &cancellables)

        vm.$isSettingsOpen
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncOverlayState()
            }
            .store(in: &cancellables)

        PreferencesManager.shared.$shortcut
            .receive(on: RunLoop.main)
            .sink { pref in
                HotkeyManager.shared.setShortcutPreference(pref)
            }
            .store(in: &cancellables)

        PreferencesManager.shared.$displayMode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, self.panel.isVisible else { return }
                self.updatePanelFrame(animate: true)
            }
            .store(in: &cancellables)
    }

    public var isVisible: Bool {
        panel.isVisible
    }

    public func syncOverlayState() {
        HotkeyManager.shared.updateOverlayState(
            isVisible: panel.isVisible,
            isSearchMode: viewModel.isSearchMode,
            isSettingsOpen: viewModel.isSettingsOpen
        )
    }

    public func enterSearchMode() {
        viewModel.enterSearchMode()
        syncOverlayState()
    }

    public func handleEscape() {
        if viewModel.isSettingsOpen {
            hide()
        } else if viewModel.isSearchMode {
            if !viewModel.searchQuery.isEmpty {
                viewModel.searchQuery = ""
            } else {
                viewModel.exitSearchMode()
            }
        } else {
            hide()
        }
        syncOverlayState()
    }

    public func show() {
        PermissionsManager.shared.refresh()
        viewModel.refreshWindows()
        updatePanelFrame(animate: false)

        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        syncOverlayState()
    }

    public func hide() {
        viewModel.closeSettings()
        viewModel.exitSearchMode()
        panel.orderOut(nil)
        syncOverlayState()
    }

    public func confirmSelection() {
        guard let windowToFocus = viewModel.selectedWindow else {
            hide()
            return
        }

        hide()
        WindowManager.shared.focus(window: windowToFocus)
    }

    public func closeSelectedWindow() {
        guard let window = viewModel.selectedWindow else { return }
        WindowManager.shared.close(window: window)
        viewModel.removeWindow(id: window.id)
    }

    public func updatePanelFrame(animate: Bool) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen = screen else { return }
        let screenFrame = screen.visibleFrame
        panel.setFrame(screenFrame, display: true, animate: animate)
    }
}
