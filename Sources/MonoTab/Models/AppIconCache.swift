import AppKit

@MainActor
enum AppIconCache {
    private static var icons: [pid_t: NSImage] = [:]

    static func icon(for pid: pid_t) -> NSImage? {
        if let cached = icons[pid] { return cached }
        guard let icon = NSRunningApplication(processIdentifier: pid)?.icon else { return nil }
        icons[pid] = icon
        return icon
    }

    static func retain(pids: Set<pid_t>) {
        guard icons.count > pids.count else { return }
        icons = icons.filter { pids.contains($0.key) }
    }

    static func clear() {
        icons.removeAll()
    }
}
