import Foundation
import Observation
import ServiceManagement

enum ShortcutPreference: String, CaseIterable, Identifiable, Sendable {
    case optionTab
    case commandTab
    case both

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .optionTab: "⌥ Option + Tab"
        case .commandTab: "⌘ Command + Tab"
        case .both: "Both (⌥ & ⌘)"
        }
    }

    var shortName: String {
        switch self {
        case .optionTab: "⌥ Tab"
        case .commandTab: "⌘ Tab"
        case .both: "Both"
        }
    }

    var hint: String {
        switch self {
        case .optionTab: "Classic MonoTab shortcut without system interference."
        case .commandTab: "Replaces the default macOS application switcher."
        case .both: "Allows using both ⌥ Tab and ⌘ Tab to switch windows."
        }
    }
}

enum DisplayModePreference: String, CaseIterable, Identifiable, Sendable {
    case compact
    case fullscreen

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compact: "Floating"
        case .fullscreen: "Fullscreen"
        }
    }
}

@MainActor
@Observable
final class PreferencesManager {
    static let shared = PreferencesManager()

    private enum Key {
        static let shortcut = "monotab_shortcut_preference"
        static let displayMode = "monotab_display_mode"
        static let showMinimized = "monotab_show_minimized"
        static let showAppTabs = "monotab_show_app_tabs"
        static let currentSpaceOnly = "monotab_current_space_only"
        static let showMenuBarIcon = "monotab_show_menu_bar_icon"
    }

    var shortcut: ShortcutPreference {
        didSet {
            guard shortcut != oldValue else { return }
            UserDefaults.standard.set(shortcut.rawValue, forKey: Key.shortcut)
            HotkeyManager.shared.setShortcutPreference(shortcut)
        }
    }

    var displayMode: DisplayModePreference {
        didSet {
            guard displayMode != oldValue else { return }
            UserDefaults.standard.set(displayMode.rawValue, forKey: Key.displayMode)
        }
    }

    var showMinimizedWindows: Bool {
        didSet { UserDefaults.standard.set(showMinimizedWindows, forKey: Key.showMinimized) }
    }

    var showAppTabs: Bool {
        didSet { UserDefaults.standard.set(showAppTabs, forKey: Key.showAppTabs) }
    }

    var currentSpaceOnly: Bool {
        didSet { UserDefaults.standard.set(currentSpaceOnly, forKey: Key.currentSpaceOnly) }
    }

    var showMenuBarIcon: Bool {
        didSet {
            guard showMenuBarIcon != oldValue else { return }
            UserDefaults.standard.set(showMenuBarIcon, forKey: Key.showMenuBarIcon)
            StatusItemController.shared.setVisible(showMenuBarIcon)
        }
    }

    var launchAtLogin: Bool {
        didSet {
            guard !isRevertingLaunchAtLogin, launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin {
                    if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
                } else {
                    if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
                }
            } catch {
                AppLogger.error("Failed to update launch at login: \(error.localizedDescription)")
                isRevertingLaunchAtLogin = true
                launchAtLogin = oldValue
                isRevertingLaunchAtLogin = false
            }
        }
    }

    @ObservationIgnored private var isRevertingLaunchAtLogin = false

    private init() {
        let defaults = UserDefaults.standard
        shortcut = defaults.string(forKey: Key.shortcut).flatMap(ShortcutPreference.init) ?? .both
        displayMode = defaults.string(forKey: Key.displayMode).flatMap(DisplayModePreference.init) ?? .compact
        showMinimizedWindows = defaults.bool(forKey: Key.showMinimized)
        showAppTabs = defaults.bool(forKey: Key.showAppTabs)
        currentSpaceOnly = defaults.object(forKey: Key.currentSpaceOnly) as? Bool ?? true
        showMenuBarIcon = defaults.object(forKey: Key.showMenuBarIcon) as? Bool ?? true
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func toggleDisplayMode() {
        displayMode = displayMode == .compact ? .fullscreen : .compact
    }
}
