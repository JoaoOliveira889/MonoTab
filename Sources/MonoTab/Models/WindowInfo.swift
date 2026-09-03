import AppKit
import Foundation

public struct WindowInfo: Identifiable, Equatable, Hashable, @unchecked Sendable {
    public let id: CGWindowID
    public let pid: pid_t
    public let appName: String
    public let title: String
    public let bounds: CGRect
    public let layer: Int
    public let appIcon: NSImage?
    public let isMinimized: Bool

    public init(
        id: CGWindowID,
        pid: pid_t,
        appName: String,
        title: String,
        bounds: CGRect,
        layer: Int,
        appIcon: NSImage? = nil,
        isMinimized: Bool = false
    ) {
        self.id = id
        self.pid = pid
        self.appName = appName
        self.title = title
        self.bounds = bounds
        self.layer = layer
        self.appIcon = appIcon
        self.isMinimized = isMinimized
    }

    public var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        return appName
    }

    public func matches(query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        return appName.localizedCaseInsensitiveContains(trimmed) ||
               title.localizedCaseInsensitiveContains(trimmed)
    }

    public static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
