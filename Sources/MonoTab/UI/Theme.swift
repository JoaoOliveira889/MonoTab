import SwiftUI

nonisolated enum AccentPreference: String, PreferenceOption {
    case system
    case blue
    case purple
    case teal
    case amber
    case pink
    case graphite

    var displayName: String {
        switch self {
        case .system: "System"
        case .blue: "Blue"
        case .purple: "Purple"
        case .teal: "Teal"
        case .amber: "Amber"
        case .pink: "Pink"
        case .graphite: "Graphite"
        }
    }

    var color: Color {
        switch self {
        case .system: .accentColor
        case .blue: Color(red: 0.48, green: 0.64, blue: 0.97)
        case .purple: Color(red: 0.73, green: 0.56, blue: 0.98)
        case .teal: Color(red: 0.35, green: 0.80, blue: 0.78)
        case .amber: Color(red: 0.98, green: 0.75, blue: 0.36)
        case .pink: Color(red: 0.96, green: 0.51, blue: 0.72)
        case .graphite: Color(red: 0.62, green: 0.65, blue: 0.72)
        }
    }
}

private struct MonoAccentKey: EnvironmentKey {
    static let defaultValue: Color = .accentColor
}

private struct MonoReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var monoAccent: Color {
        get { self[MonoAccentKey.self] }
        set { self[MonoAccentKey.self] = newValue }
    }

    var monoReduceMotion: Bool {
        get { self[MonoReduceMotionKey.self] }
        set { self[MonoReduceMotionKey.self] = newValue }
    }
}

extension View {
    func monoAnimation<Value: Equatable>(_ animation: Animation, value: Value, enabled: Bool) -> some View {
        self.animation(enabled ? animation : nil, value: value)
    }
}
