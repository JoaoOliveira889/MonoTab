import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import ScreenCaptureKit
import Synchronization

@_silgen_name("_AXUIElementGetWindow")
private func axWindowID(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

final class WindowManager: Sendable {
    static let shared = WindowManager()

    private static let axMessagingTimeout: Float = 0.05
    private static let axActionTimeout: Float = 0.5
    private static let thumbnailCacheLimit = 48
    private static let maxConcurrentCaptures = 4
    private static let browserNames = ["safari", "chrome", "arc", "firefox", "brave", "edge"]

    private struct ThumbnailStore {
        var images: [CGWindowID: CGImage] = [:]
        var insertionOrder: [CGWindowID] = []
    }

    private let thumbnails = Mutex(ThumbnailStore())

    private init() {}

    // MARK: - Thumbnail cache

    func cachedThumbnail(for windowID: CGWindowID) -> CGImage? {
        thumbnails.withLock { $0.images[windowID] }
    }

    func clearCache() {
        thumbnails.withLock {
            $0.images.removeAll()
            $0.insertionOrder.removeAll()
        }
    }

    private func store(_ image: CGImage, for windowID: CGWindowID) {
        thumbnails.withLock { store in
            if store.images.updateValue(image, forKey: windowID) == nil {
                store.insertionOrder.append(windowID)
            }
            guard store.images.count > Self.thumbnailCacheLimit else { return }
            let excess = store.images.count - Self.thumbnailCacheLimit
            for evicted in store.insertionOrder.prefix(excess) {
                store.images.removeValue(forKey: evicted)
            }
            store.insertionOrder.removeFirst(excess)
        }
    }

    private func purgeThumbnails(keeping liveIDs: Set<CGWindowID>) {
        thumbnails.withLock { store in
            guard store.images.count > liveIDs.count else { return }
            store.images = store.images.filter { liveIDs.contains($0.key) }
            store.insertionOrder.removeAll { !liveIDs.contains($0) }
        }
    }

    func fetchOnScreenWindows() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let raw = (CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]) ?? []

        var apps = AppLookup()
        var results: [WindowInfo] = []
        results.reserveCapacity(raw.count)

        for info in raw {
            guard let candidate = Candidate(info, minimumSide: 60, apps: &apps) else { continue }
            if info[kCGWindowIsOnscreen as String] as? Bool == false { continue }
            if candidate.title.isEmpty, Self.requiresTitle(appName: candidate.appName) { continue }

            results.append(candidate.windowInfo(isMinimized: false))
        }

        purgeThumbnails(keeping: Set(results.map(\.id)))
        return results
    }

    func fetchExtendedWindows(
        base: [WindowInfo],
        includeMinimized: Bool,
        showTabs: Bool,
        currentSpaceOnly: Bool
    ) async -> [WindowInfo] {
        var results = base
        var seenIDs = Set(base.map(\.id))
        let allWindows = (CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []

        var byWindowID: [CGWindowID: [String: Any]] = [:]
        var byPID: [pid_t: [[String: Any]]] = [:]
        byWindowID.reserveCapacity(allWindows.count)
        for info in allWindows {
            guard let number = info[kCGWindowNumber as String] as? NSNumber,
                  let ownerPID = info[kCGWindowOwnerPID as String] as? NSNumber else { continue }
            byWindowID[CGWindowID(number.uint32Value)] = info
            byPID[pid_t(ownerPID.int32Value), default: []].append(info)
        }

        var apps = AppLookup()

        if includeMinimized {
            let candidatePIDs = NSWorkspace.shared.runningApplications.compactMap { app -> pid_t? in
                guard app.activationPolicy == .regular, app.processIdentifier != apps.currentPID else { return nil }
                return app.processIdentifier
            }

            for minimized in await Self.collectMinimizedWindows(pids: candidatePIDs) {
                var windowID = minimized.windowID
                var matched = windowID > 0 ? byWindowID[windowID] : nil

                if matched == nil, let candidates = byPID[minimized.pid] {
                    matched = candidates.first { info in
                        guard let id = Self.windowID(info), !seenIDs.contains(id) else { return false }
                        return !minimized.title.isEmpty && info[kCGWindowName as String] as? String == minimized.title
                    } ?? candidates.first { info in
                        guard let id = Self.windowID(info) else { return false }
                        return !seenIDs.contains(id)
                    }
                    if let matched, let id = Self.windowID(matched) { windowID = id }
                }

                guard windowID > 0, seenIDs.insert(windowID).inserted else { continue }

                let bounds = matched.flatMap(Self.bounds) ?? minimized.bounds
                let appName = matched?[kCGWindowOwnerName as String] as? String
                    ?? apps.name(for: minimized.pid)
                    ?? "App"
                let title = minimized.title.isEmpty
                    ? (matched?[kCGWindowName as String] as? String ?? "")
                    : minimized.title

                Self.insertGrouped(
                    WindowInfo(
                        id: windowID,
                        pid: minimized.pid,
                        appName: appName,
                        title: title,
                        bounds: bounds,
                        isMinimized: true
                    ),
                    into: &results
                )
            }
        }

        if showTabs || !currentSpaceOnly {
            var onScreenPIDs = Set(base.map(\.pid))

            for info in allWindows {
                guard let candidate = Candidate(info, minimumSide: 120, apps: &apps) else { continue }
                if seenIDs.contains(candidate.id) { continue }
                if candidate.title.isEmpty { continue }
                if showTabs, currentSpaceOnly, !onScreenPIDs.contains(candidate.pid) { continue }

                seenIDs.insert(candidate.id)
                onScreenPIDs.insert(candidate.pid)
                Self.insertGrouped(candidate.windowInfo(isMinimized: false), into: &results)
            }
        }

        purgeThumbnails(keeping: seenIDs)
        return results
    }

    private static func insertGrouped(_ window: WindowInfo, into results: inout [WindowInfo]) {
        if let lastOfSameApp = results.lastIndex(where: { $0.pid == window.pid }) {
            results.insert(window, at: lastOfSameApp + 1)
        } else {
            results.append(window)
        }
    }

    private static func requiresTitle(appName: String) -> Bool {
        let lower = appName.lowercased()
        return browserNames.contains { lower.contains($0) }
    }

    private static func windowID(_ info: [String: Any]) -> CGWindowID? {
        (info[kCGWindowNumber as String] as? NSNumber).map { CGWindowID($0.uint32Value) }
    }

    private static func bounds(_ info: [String: Any]) -> CGRect? {
        guard let dictionary = info[kCGWindowBounds as String] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: dictionary)
    }

    private struct AppLookup {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        private var names: [pid_t: String?] = [:]

        mutating func name(for pid: pid_t) -> String? {
            if let cached = names[pid] { return cached }
            let app = NSRunningApplication(processIdentifier: pid)
            let resolved = app?.activationPolicy == .regular ? (app?.localizedName ?? "App") : nil
            names[pid] = resolved
            return resolved
        }
    }

    private struct Candidate {
        let id: CGWindowID
        let pid: pid_t
        let appName: String
        let title: String
        let bounds: CGRect

        init?(_ info: [String: Any], minimumSide: CGFloat, apps: inout AppLookup) {
            guard let id = WindowManager.windowID(info),
                  let ownerPID = info[kCGWindowOwnerPID as String] as? NSNumber else { return nil }
            let pid = pid_t(ownerPID.int32Value)
            guard pid != apps.currentPID else { return nil }
            guard (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0 else { return nil }
            guard (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1.0 >= 0.05 else { return nil }
            guard let bounds = WindowManager.bounds(info),
                  bounds.width >= minimumSide,
                  bounds.height >= minimumSide,
                  bounds.origin.x >= -2000 else { return nil }
            guard let ownerName = apps.name(for: pid) else { return nil }
            let appName = info[kCGWindowOwnerName as String] as? String ?? ownerName

            self.id = id
            self.pid = pid
            self.appName = appName
            self.bounds = bounds
            self.title = (info[kCGWindowName as String] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func windowInfo(isMinimized: Bool) -> WindowInfo {
            WindowInfo(id: id, pid: pid, appName: appName, title: title, bounds: bounds, isMinimized: isMinimized)
        }
    }

    private struct MinimizedWindow: Sendable {
        let pid: pid_t
        let windowID: CGWindowID
        let title: String
        let bounds: CGRect
    }

    private static func collectMinimizedWindows(pids: [pid_t]) async -> [MinimizedWindow] {
        guard !pids.isEmpty else { return [] }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let collected = Mutex<[MinimizedWindow]>([])
                DispatchQueue.concurrentPerform(iterations: pids.count) { index in
                    let found = minimizedWindows(pid: pids[index])
                    guard !found.isEmpty else { return }
                    collected.withLock { $0.append(contentsOf: found) }
                }
                continuation.resume(returning: collected.withLock { $0 })
            }
        }
    }

    private static func axWindows(pid: pid_t, timeout: Float) -> [AXUIElement] {
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, timeout)

        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            return []
        }
        return windows
    }

    private static func minimizedWindows(pid: pid_t) -> [MinimizedWindow] {
        let axWindows = axWindows(pid: pid, timeout: axMessagingTimeout)
        guard !axWindows.isEmpty else { return [] }

        var results: [MinimizedWindow] = []
        for axWindow in axWindows {
            var minimizedRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axWindow, kAXMinimizedAttribute as CFString, &minimizedRef) == .success,
                  (minimizedRef as? NSNumber)?.boolValue == true else {
                continue
            }

            var windowID: CGWindowID = 0
            if axWindowID(axWindow, &windowID) != .success { windowID = 0 }

            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef)

            results.append(
                MinimizedWindow(
                    pid: pid,
                    windowID: windowID,
                    title: (titleRef as? String) ?? "",
                    bounds: windowID > 0 ? .zero : axFrame(of: axWindow)
                )
            )
        }
        return results
    }

    private static func axFrame(of element: AXUIElement) -> CGRect {
        var origin = CGPoint.zero
        var size = CGSize(width: 800, height: 600)

        var positionRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
           let value = positionRef, CFGetTypeID(value) == AXValueGetTypeID() {
            AXValueGetValue(unsafeDowncast(value as AnyObject, to: AXValue.self), .cgPoint, &origin)
        }
        var sizeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
           let value = sizeRef, CFGetTypeID(value) == AXValueGetTypeID() {
            AXValueGetValue(unsafeDowncast(value as AnyObject, to: AXValue.self), .cgSize, &size)
        }
        return CGRect(origin: origin, size: size)
    }

    private static func resolve(_ window: WindowInfo, among axWindows: [AXUIElement]) -> AXUIElement? {
        for axWindow in axWindows {
            var id: CGWindowID = 0
            if axWindowID(axWindow, &id) == .success, id == window.id {
                return axWindow
            }
        }

        guard !window.title.isEmpty else { return axWindows.first }

        for axWindow in axWindows {
            var titleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef) == .success,
               titleRef as? String == window.title {
                return axWindow
            }
        }
        return axWindows.first
    }

    private func performOnTargetAXWindow(for window: WindowInfo, action: @escaping @Sendable (AXUIElement) -> Void) {
        Task.detached(priority: .userInitiated) {
            let axWindows = Self.axWindows(pid: window.pid, timeout: Self.axActionTimeout)
            guard let target = Self.resolve(window, among: axWindows) else { return }
            action(target)
        }
    }

    func focus(window: WindowInfo) {
        guard let app = NSRunningApplication(processIdentifier: window.pid) else { return }
        if app.isHidden { app.unhide() }
        app.activate()

        performOnTargetAXWindow(for: window) { target in
            var minimizedRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(target, kAXMinimizedAttribute as CFString, &minimizedRef) == .success,
               (minimizedRef as? NSNumber)?.boolValue == true {
                AXUIElementSetAttributeValue(target, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            }

            AXUIElementSetAttributeValue(target, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(target, kAXRaiseAction as CFString)
        }
    }

    func quitApplication(pid: pid_t) {
        NSRunningApplication(processIdentifier: pid)?.terminate()
    }

    func close(window: WindowInfo) {
        performOnTargetAXWindow(for: window) { target in
            var closeButtonRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(target, kAXCloseButtonAttribute as CFString, &closeButtonRef) == .success,
                  let closeButton = closeButtonRef,
                  CFGetTypeID(closeButton) == AXUIElementGetTypeID() else {
                return
            }
            AXUIElementPerformAction(unsafeDowncast(closeButton as AnyObject, to: AXUIElement.self), kAXPressAction as CFString)
        }
    }

    private struct Unchecked<Value>: @unchecked Sendable {
        let value: Value

        init(_ value: Value) { self.value = value }
    }

    func captureThumbnails(
        for windows: [WindowInfo],
        priorityID: CGWindowID?,
        onCapture: @escaping @Sendable @MainActor (CGWindowID, CGImage) -> Void
    ) async {
        guard !windows.isEmpty,
              let shareable = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true),
              !Task.isCancelled else {
            return
        }

        var scWindows: [CGWindowID: SCWindow] = [:]
        scWindows.reserveCapacity(shareable.windows.count)
        for window in shareable.windows { scWindows[window.windowID] = window }

        var ordered = windows.filter { scWindows[$0.id] != nil }
        if let priorityID, let index = ordered.firstIndex(where: { $0.id == priorityID }) {
            ordered.insert(ordered.remove(at: index), at: 0)
        }
        guard !ordered.isEmpty else { return }

        await withTaskGroup(of: (CGWindowID, CGImage)?.self) { group in
            var next = 0
            let inFlight = min(Self.maxConcurrentCaptures, ordered.count)

            func schedule() {
                guard next < ordered.count else { return }
                let window = ordered[next]
                next += 1
                guard let match = scWindows[window.id] else { return }
                let scWindow = Unchecked(match)
                group.addTask { [self] in
                    guard let image = await capture(scWindow.value, aspectOf: window.bounds) else { return nil }
                    return (window.id, image)
                }
            }

            for _ in 0..<inFlight { schedule() }

            while let result = await group.next() {
                if Task.isCancelled { group.cancelAll(); return }
                if let (id, image) = result {
                    await onCapture(id, image)
                }
                schedule()
            }
        }
    }

    private func capture(_ scWindow: SCWindow, aspectOf bounds: CGRect) async -> CGImage? {
        let configuration = SCStreamConfiguration()
        let (width, height) = Self.thumbnailPixelSize(for: bounds)
        configuration.width = width
        configuration.height = height
        configuration.showsCursor = false
        configuration.scalesToFit = true
        configuration.ignoreShadowsSingleWindow = true
        configuration.pixelFormat = kCVPixelFormatType_32BGRA

        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        guard let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) else {
            return nil
        }
        store(image, for: scWindow.windowID)
        return image
    }

    private static func thumbnailPixelSize(for bounds: CGRect) -> (width: Int, height: Int) {
        let maxWidth: CGFloat = 560
        let maxHeight: CGFloat = 352
        guard bounds.width > 0, bounds.height > 0 else { return (Int(maxWidth), Int(maxHeight)) }

        let aspect = bounds.width / bounds.height
        var width = maxWidth
        var height = maxWidth / aspect
        if height > maxHeight {
            height = maxHeight
            width = maxHeight * aspect
        }
        return (max(2, Int(width.rounded())), max(2, Int(height.rounded())))
    }
}
