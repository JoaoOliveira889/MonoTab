import AppKit

@MainActor
final class StatusItemController: NSObject {
    static let shared = StatusItemController()

    private var statusItem: NSStatusItem?

    private override init() {
        super.init()
    }

    func setVisible(_ visible: Bool) {
        guard visible else {
            if let statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
            statusItem = nil
            return
        }
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "macwindow.on.rectangle",
            accessibilityDescription: "MonoTab"
        )
        item.button?.image?.isTemplate = true
        item.menu = makeMenu()
        statusItem = item
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let open = NSMenuItem(title: "Open Switcher", action: #selector(openSwitcher), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let preferences = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        preferences.target = self
        menu.addItem(preferences)

        menu.addItem(.separator())

        let permissions = NSMenuItem(
            title: "Open Accessibility Settings",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        permissions.target = self
        menu.addItem(permissions)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit MonoTab", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc private func openSwitcher() {
        SwitcherPanelController.shared.show()
    }

    @objc private func openPreferences() {
        SwitcherPanelController.shared.showPreferences()
    }

    @objc private func openAccessibilitySettings() {
        PermissionsManager.shared.openAccessibilityPreferences()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
