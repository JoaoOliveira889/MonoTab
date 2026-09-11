import AppKit
import CoreGraphics

final class WindowActivationHistory {
    static let shared = WindowActivationHistory()

    private static let limit = 256

    private var windowOrder: [CGWindowID] = []
    private var appOrder: [pid_t] = []

    private init() {}

    func startObservingApplicationActivation() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            let key = NSWorkspace.applicationUserInfoKey
            guard let app = notification.userInfo?[key] as? NSRunningApplication else { return }
            MainActor.assumeIsolated {
                WindowActivationHistory.shared.record(pid: app.processIdentifier)
            }
        }
    }

    func record(window: WindowInfo) {
        windowOrder.removeAll { $0 == window.id }
        windowOrder.insert(window.id, at: 0)
        if windowOrder.count > Self.limit { windowOrder.removeLast(windowOrder.count - Self.limit) }
        record(pid: window.pid)
    }

    func record(pid: pid_t) {
        appOrder.removeAll { $0 == pid }
        appOrder.insert(pid, at: 0)
        if appOrder.count > Self.limit { appOrder.removeLast(appOrder.count - Self.limit) }
    }

    func forget(windowID: CGWindowID) {
        windowOrder.removeAll { $0 == windowID }
    }

    func forget(pid: pid_t) {
        appOrder.removeAll { $0 == pid }
    }

    func ordered(_ windows: [WindowInfo]) -> [WindowInfo] {
        guard windows.count > 1, !windowOrder.isEmpty || !appOrder.isEmpty else { return windows }

        var windowRank: [CGWindowID: Int] = [:]
        windowRank.reserveCapacity(windowOrder.count)
        for (rank, id) in windowOrder.enumerated() where windowRank[id] == nil {
            windowRank[id] = rank
        }

        var appRank: [pid_t: Int] = [:]
        appRank.reserveCapacity(appOrder.count)
        for (rank, pid) in appOrder.enumerated() where appRank[pid] == nil {
            appRank[pid] = rank
        }

        let unseen = Int.max
        return windows.enumerated()
            .sorted { lhs, rhs in
                let leftWindow = windowRank[lhs.element.id] ?? unseen
                let rightWindow = windowRank[rhs.element.id] ?? unseen
                if leftWindow != rightWindow { return leftWindow < rightWindow }

                let leftApp = appRank[lhs.element.pid] ?? unseen
                let rightApp = appRank[rhs.element.pid] ?? unseen
                if leftApp != rightApp { return leftApp < rightApp }

                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}
