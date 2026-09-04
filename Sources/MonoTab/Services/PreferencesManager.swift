import Combine
import Foundation
import ServiceManagement

public enum ShortcutPreference: String, CaseIterable, Identifiable {
    case optionTab = "optionTab"
    case commandTab = "commandTab"
    case both = "both"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .optionTab: return "⌥ Option + Tab"
        case .commandTab: return "⌘ Command + Tab"
        case .both: return "Both (⌥ & ⌘)"
        }
    }

    public var shortName: String {
        switch self {
        case .optionTab: return "⌥ Tab"
        case .commandTab: return "⌘ Tab"
        case .both: return "Both"
        }
    }

    public var hint: String {
        switch self {
        case .optionTab: return "Classic MonoTab shortcut without system interference."
        case .commandTab: return "Replaces the default macOS application switcher."
        case .both: return "Allows using both ⌥ Tab and ⌘ Tab to switch windows."
        }
    }
}

public enum DisplayModePreference: String, CaseIterable, Identifiable {
    case compact = "compact"
    case fullscreen = "fullscreen"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .compact: return "Floating"
        case .fullscreen: return "Fullscreen"
        }
    }
}

@MainActor
public final class PreferencesManager: ObservableObject {
    public static let shared = PreferencesManager()

    private let kShortcutKey = "monotab_shortcut_preference"
    private let kDisplayModeKey = "monotab_display_mode"
    private let kShowMinimizedKey = "monotab_show_minimized"
    private let kShowAppTabsKey = "monotab_show_app_tabs"
    private let kCurrentSpaceOnlyKey = "monotab_current_space_only"

    @Published public var shortcut: ShortcutPreference {
        didSet {
            UserDefaults.standard.set(shortcut.rawValue, forKey: kShortcutKey)
        }
    }

    @Published public var displayMode: DisplayModePreference {
        didSet {
            UserDefaults.standard.set(displayMode.rawValue, forKey: kDisplayModeKey)
        }
    }

    @Published public var showMinimizedWindows: Bool {
        didSet {
            UserDefaults.standard.set(showMinimizedWindows, forKey: kShowMinimizedKey)
        }
    }

    @Published public var showAppTabs: Bool {
        didSet {
            UserDefaults.standard.set(showAppTabs, forKey: kShowAppTabsKey)
        }
    }

    @Published public var currentSpaceOnly: Bool {
        didSet {
            UserDefaults.standard.set(currentSpaceOnly, forKey: kCurrentSpaceOnlyKey)
        }
    }

    public var launchAtLogin: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            objectWillChange.send()
            do {
                if newValue {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                AppLogger.error("Error configuring launch at login: \(error)")
            }
        }
    }

    private init() {
        let savedShortcut = UserDefaults.standard.string(forKey: kShortcutKey) ?? ShortcutPreference.both.rawValue
        self.shortcut = ShortcutPreference(rawValue: savedShortcut) ?? .both

        let savedDisplayMode = UserDefaults.standard.string(forKey: kDisplayModeKey) ?? DisplayModePreference.compact.rawValue
        self.displayMode = DisplayModePreference(rawValue: savedDisplayMode) ?? .compact

        self.showMinimizedWindows = UserDefaults.standard.bool(forKey: kShowMinimizedKey)
        self.showAppTabs = UserDefaults.standard.bool(forKey: kShowAppTabsKey)
        self.currentSpaceOnly = UserDefaults.standard.object(forKey: kCurrentSpaceOnlyKey) as? Bool ?? true
    }

    public func toggleDisplayMode() {
        displayMode = (displayMode == .compact) ? .fullscreen : .compact
    }
}
