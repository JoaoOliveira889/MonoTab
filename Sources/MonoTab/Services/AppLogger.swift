import Foundation
import os

public enum AppLogger {
    public static let general = Logger(subsystem: "com.antigravity.monotab", category: "General")
    public static let hotkey = Logger(subsystem: "com.antigravity.monotab", category: "Hotkey")
    public static let window = Logger(subsystem: "com.antigravity.monotab", category: "Window")
    public static let ui = Logger(subsystem: "com.antigravity.monotab", category: "UI")

    @inlinable
    public static func debug(_ message: String, category: Logger = general) {
        #if DEBUG
        category.debug("\(message, privacy: .public)")
        #endif
    }

    @inlinable
    public static func error(_ message: String, category: Logger = general) {
        category.error("\(message, privacy: .public)")
    }
}

/// Zero-cost non-blocking logger in production that uses Apple Unified Logging in debug builds.
/// Never touches the filesystem or external network.
@inlinable
public func debugLog(_ message: String) {
    #if DEBUG
    AppLogger.debug(message)
    #endif
}
