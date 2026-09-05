import os

enum AppLogger {
    static let general = Logger(subsystem: "com.antigravity.monotab", category: "General")

    static func error(_ message: String) {
        general.error("\(message, privacy: .public)")
    }
}
