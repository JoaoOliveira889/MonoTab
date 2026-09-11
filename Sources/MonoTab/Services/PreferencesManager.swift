import Foundation
import Observation
import ServiceManagement

nonisolated protocol PreferenceOption: RawRepresentable, CaseIterable, Identifiable, Sendable where RawValue == String {
    var displayName: String { get }
}

extension PreferenceOption {
    nonisolated var id: String { rawValue }
}

nonisolated enum ShortcutPreference: String, PreferenceOption {
    case optionTab
    case commandTab
    case both

    var displayName: String {
        switch self {
        case .optionTab: "Option + Tab"
        case .commandTab: "Command + Tab"
        case .both: "Both"
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
        case .optionTab: "Classic MonoTab shortcut, no system interference."
        case .commandTab: "Replaces the default macOS application switcher."
        case .both: "Accepts ⌥ Tab and ⌘ Tab to switch windows."
        }
    }
}

nonisolated enum DisplayModePreference: String, PreferenceOption {
    case compact
    case fullscreen

    var displayName: String {
        switch self {
        case .compact: "Floating"
        case .fullscreen: "Fullscreen"
        }
    }
}

nonisolated enum ScreenTargetPreference: String, PreferenceOption {
    case mouseLocation
    case activeWindow

    var displayName: String {
        switch self {
        case .mouseLocation: "Under Mouse Pointer"
        case .activeWindow: "Screen with Active Window"
        }
    }
}

@Observable
final class PreferencesManager {
    static let shared = PreferencesManager()

    private enum Key {
        static let shortcut = "monotab_shortcut_preference"
        static let displayMode = "monotab_display_mode"
        static let showMinimized = "monotab_show_minimized"
        static let groupBrowserTabs = "monotab_group_browser_tabs"
        static let legacyShowAppTabs = "monotab_show_app_tabs"
        static let currentSpaceOnly = "monotab_current_space_only"
        static let showMenuBarIcon = "monotab_show_menu_bar_icon"
        static let screenTarget = "monotab_screen_target"
        static let showQuickShortcuts = "monotab_show_quick_shortcuts"
        static let accent = "monotab_accent"
        static let recentOrdering = "monotab_recent_ordering"
        static let confirmDestructive = "monotab_confirm_destructive"
    }

    private let defaults = UserDefaults.standard

    var shortcut: ShortcutPreference {
        didSet {
            guard shortcut != oldValue else { return }
            defaults.set(shortcut.rawValue, forKey: Key.shortcut)
            HotkeyManager.shared.setShortcutPreference(shortcut)
        }
    }

    var displayMode: DisplayModePreference {
        didSet { defaults.set(displayMode.rawValue, forKey: Key.displayMode) }
    }

    var screenTarget: ScreenTargetPreference {
        didSet { defaults.set(screenTarget.rawValue, forKey: Key.screenTarget) }
    }

    var accent: AccentPreference {
        didSet { defaults.set(accent.rawValue, forKey: Key.accent) }
    }

    var showQuickShortcuts: Bool {
        didSet { defaults.set(showQuickShortcuts, forKey: Key.showQuickShortcuts) }
    }

    var showMinimizedWindows: Bool {
        didSet { defaults.set(showMinimizedWindows, forKey: Key.showMinimized) }
    }

    var groupBrowserTabs: Bool {
        didSet { defaults.set(groupBrowserTabs, forKey: Key.groupBrowserTabs) }
    }

    var currentSpaceOnly: Bool {
        didSet { defaults.set(currentSpaceOnly, forKey: Key.currentSpaceOnly) }
    }

    var useRecentOrdering: Bool {
        didSet { defaults.set(useRecentOrdering, forKey: Key.recentOrdering) }
    }

    var confirmDestructiveActions: Bool {
        didSet { defaults.set(confirmDestructiveActions, forKey: Key.confirmDestructive) }
    }

    var showMenuBarIcon: Bool {
        didSet {
            guard showMenuBarIcon != oldValue else { return }
            defaults.set(showMenuBarIcon, forKey: Key.showMenuBarIcon)
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

    var showAppTabs: Bool { !groupBrowserTabs }

    private init() {
        let defaults = UserDefaults.standard
        shortcut = defaults.option(Key.shortcut, default: .both)
        displayMode = defaults.option(Key.displayMode, default: .compact)
        screenTarget = defaults.option(Key.screenTarget, default: .mouseLocation)
        accent = defaults.option(Key.accent, default: .system)
        showQuickShortcuts = defaults.flag(Key.showQuickShortcuts, default: true)
        showMinimizedWindows = defaults.flag(Key.showMinimized, default: false)
        currentSpaceOnly = defaults.flag(Key.currentSpaceOnly, default: true)
        showMenuBarIcon = defaults.flag(Key.showMenuBarIcon, default: true)
        useRecentOrdering = defaults.flag(Key.recentOrdering, default: true)
        confirmDestructiveActions = defaults.flag(Key.confirmDestructive, default: true)
        groupBrowserTabs = defaults.flag(
            Key.groupBrowserTabs,
            default: !defaults.flag(Key.legacyShowAppTabs, default: false)
        )
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func toggleDisplayMode() {
        displayMode = displayMode == .compact ? .fullscreen : .compact
    }

    func restoreDefaults() {
        shortcut = .both
        displayMode = .compact
        screenTarget = .mouseLocation
        accent = .system
        showQuickShortcuts = true
        showMinimizedWindows = false
        groupBrowserTabs = true
        currentSpaceOnly = true
        useRecentOrdering = true
        confirmDestructiveActions = true
        showMenuBarIcon = true
    }
}

private extension UserDefaults {
    func flag(_ key: String, default fallback: Bool) -> Bool {
        object(forKey: key) as? Bool ?? fallback
    }

    func option<Option: PreferenceOption>(_ key: String, default fallback: Option) -> Option {
        string(forKey: key).flatMap(Option.init(rawValue:)) ?? fallback
    }
}
