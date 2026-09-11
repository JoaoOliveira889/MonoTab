import AppKit

final class StatusItemController: NSObject {
    static let shared = StatusItemController()

    private var statusItem: NSStatusItem?
    private var visibilityObservation: NSKeyValueObservation?

    private override init() {
        super.init()
    }

    func setVisible(_ visible: Bool) {
        guard visible else {
            visibilityObservation = nil
            if let statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
            statusItem = nil
            return
        }
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "MonoTabStatusItem"
        item.behavior = .removalAllowed
        item.button?.image = Self.menuBarImage()
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.toolTip = "MonoTab — click to open the switcher"
        item.button?.setAccessibilityLabel("MonoTab")
        item.isVisible = true

        visibilityObservation = item.observe(\.isVisible, options: [.new]) { _, change in
            guard let isVisible = change.newValue else { return }
            MainActor.assumeIsolated {
                if PreferencesManager.shared.showMenuBarIcon != isVisible {
                    PreferencesManager.shared.showMenuBarIcon = isVisible
                }
            }
        }

        statusItem = item
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else {
            SwitcherPanelController.shared.show()
            return
        }

        let isSecondary = event.type == .rightMouseUp || event.modifierFlags.contains(.control)
        guard isSecondary else {
            toggleSwitcher()
            return
        }

        guard let statusItem else { return }
        statusItem.menu = makeMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func toggleSwitcher() {
        let controller = SwitcherPanelController.shared
        if controller.isVisible {
            controller.hide()
        } else {
            controller.show()
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let entries: [(title: String, selector: Selector, key: String)] = [
            ("Open Switcher", #selector(openSwitcher), ""),
            ("Keyboard Shortcuts…", #selector(openShortcuts), "?"),
            ("Preferences…", #selector(openPreferences), ",")
        ]

        for entry in entries {
            let item = NSMenuItem(title: entry.title, action: entry.selector, keyEquivalent: entry.key)
            item.target = self
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let permissions = NSMenuItem(
            title: "Open Accessibility Settings",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        permissions.target = self
        menu.addItem(permissions)

        menu.addItem(.separator())

        let version = NSMenuItem(title: "MonoTab v\(AppInfo.bundleVersion)", action: nil, keyEquivalent: "")
        version.isEnabled = false
        menu.addItem(version)

        let quit = NSMenuItem(title: "Quit MonoTab", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    private static func menuBarImage() -> NSImage {
        let size = NSSize(width: 18, height: 16)
        let image = NSImage(size: size)

        image.lockFocus()
        NSColor.black.setStroke()
        NSColor.black.setFill()

        let back = NSBezierPath(roundedRect: NSRect(x: 1, y: 5, width: 10.5, height: 8.5), xRadius: 2, yRadius: 2)
        back.lineWidth = 1.3
        back.stroke()

        NSGraphicsContext.current?.compositingOperation = .clear
        NSBezierPath(
            roundedRect: NSRect(x: 5.2, y: 1.2, width: 12.1, height: 10.1),
            xRadius: 3,
            yRadius: 3
        ).fill()

        NSGraphicsContext.current?.compositingOperation = .sourceOver
        let front = NSBezierPath(roundedRect: NSRect(x: 6, y: 2, width: 11, height: 9), xRadius: 2.5, yRadius: 2.5)
        front.fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    @objc private func openSwitcher() {
        SwitcherPanelController.shared.show()
    }

    @objc private func openPreferences() {
        SwitcherPanelController.shared.showPreferences()
    }

    @objc private func openShortcuts() {
        let controller = SwitcherPanelController.shared
        if !controller.isVisible { controller.show() }
        controller.viewModel.isHelpOpen = true
    }

    @objc private func openAccessibilitySettings() {
        PermissionsManager.shared.openSettings(for: .accessibility)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
