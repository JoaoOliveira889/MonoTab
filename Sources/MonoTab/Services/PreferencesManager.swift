import Combine
import Foundation

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

    private init() {
        let savedShortcut = UserDefaults.standard.string(forKey: kShortcutKey) ?? ShortcutPreference.both.rawValue
        self.shortcut = ShortcutPreference(rawValue: savedShortcut) ?? .both

        let savedDisplayMode = UserDefaults.standard.string(forKey: kDisplayModeKey) ?? DisplayModePreference.compact.rawValue
        self.displayMode = DisplayModePreference(rawValue: savedDisplayMode) ?? .compact

        self.showMinimizedWindows = UserDefaults.standard.bool(forKey: kShowMinimizedKey)
    }

    public func toggleDisplayMode() {
        displayMode = (displayMode == .compact) ? .fullscreen : .compact
    }
}
