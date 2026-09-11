import Foundation

nonisolated enum AppInfo {
    static let version = "0.1.0"
    static let build = "2"

    static var bundleVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? version
    }

    static var bundleBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? build
    }
}
