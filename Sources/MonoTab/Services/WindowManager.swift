import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Foundation
import ScreenCaptureKit
import Synchronization

private typealias AXWindowIDFunction = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError

private nonisolated let axWindowIDSymbol: AXWindowIDFunction? = {
    guard let defaultHandle = UnsafeMutableRawPointer(bitPattern: -2),
          let symbol = dlsym(defaultHandle, "_AXUIElementGetWindow") else {
        return nil
    }
    return unsafeBitCast(symbol, to: AXWindowIDFunction.self)
}()

private nonisolated func axWindowID(of element: AXUIElement) -> CGWindowID? {
    guard let axWindowIDSymbol else { return nil }
    var id: CGWindowID = 0
    guard axWindowIDSymbol(element, &id) == .success, id > 0 else { return nil }
    return id
}

nonisolated final class WindowManager: Sendable {
    static let shared = WindowManager()

    private static let axMessagingTimeout: Float = 0.05
    private static let axActionTimeout: Float = 0.5
    private static let thumbnailCacheLimit = 48
    private static let maxConcurrentCaptures = 4
    private static let thumbnailFreshness = Duration.seconds(2)
    private static let shareableContentLifetime = Duration.milliseconds(1500)
    private static let browserNames = ["safari", "chrome", "arc", "firefox", "brave", "edge"]

    private struct Unchecked<Value>: @unchecked Sendable {
        let value: Value

        init(_ value: Value) { self.value = value }
    }

    private struct CachedThumbnail {
        let image: CGImage
        let bounds: CGRect
        let capturedAt: ContinuousClock.Instant
    }

    private struct ThumbnailStore {
        var entries: [CGWindowID: CachedThumbnail] = [:]
        var insertionOrder: [CGWindowID] = []
    }

    private struct ShareableCache {
        var windows: Unchecked<[CGWindowID: SCWindow]>?
        var fetchedAt: ContinuousClock.Instant?
    }

    private let thumbnails = Mutex(ThumbnailStore())
    private let appsCache = Mutex(AppLookup())
    private let shareable = Mutex(ShareableCache())

    private init() {}

    // MARK: - Thumbnail cache

    func cachedThumbnail(for windowID: CGWindowID) -> CGImage? {
        thumbnails.withLock { $0.entries[windowID]?.image }
    }

    func clearCache() {
        thumbnails.withLock {
            $0.entries.removeAll()
            $0.insertionOrder.removeAll()
        }
        appsCache.withLock { $0.purge() }
        shareable.withLock {
            $0.windows = nil
            $0.fetchedAt = nil
        }
    }

    private func store(_ image: CGImage, for windowID: CGWindowID, bounds: CGRect) {
        thumbnails.withLock { store in
            let entry = CachedThumbnail(image: image, bounds: bounds, capturedAt: ContinuousClock.now)
            if store.entries.updateValue(entry, forKey: windowID) == nil {
                store.insertionOrder.append(windowID)
            }
            guard store.entries.count > Self.thumbnailCacheLimit else { return }
            let excess = store.entries.count - Self.thumbnailCacheLimit
            for evicted in store.insertionOrder.prefix(excess) {
                store.entries.removeValue(forKey: evicted)
            }
            store.insertionOrder.removeFirst(excess)
        }
    }

    private func isFresh(_ window: WindowInfo, now: ContinuousClock.Instant) -> Bool {
        thumbnails.withLock { store in
            guard let entry = store.entries[window.id] else { return false }
            return entry.bounds == window.bounds && now - entry.capturedAt < Self.thumbnailFreshness
        }
    }

    private func purgeThumbnails(keeping liveIDs: Set<CGWindowID>) {
        thumbnails.withLock { store in
            guard store.entries.count > liveIDs.count else { return }
            store.entries = store.entries.filter { liveIDs.contains($0.key) }
            store.insertionOrder.removeAll { !liveIDs.contains($0) }
        }
    }

    // MARK: - Enumeration

    func fetchOnScreenWindows(screens: ScreenSnapshot) -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let raw = (CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]) ?? []

        var results: [WindowInfo] = []
        results.reserveCapacity(raw.count)

        appsCache.withLock { apps in
            for info in raw {
                guard let candidate = Candidate(info, minimumSide: 60, apps: &apps) else { continue }
                if info[kCGWindowIsOnscreen as String] as? Bool == false { continue }
                if candidate.title.isEmpty, Self.requiresTitle(appName: candidate.appName) { continue }

                results.append(candidate.windowInfo(isMinimized: false, screens: screens))
            }
        }

        purgeThumbnails(keeping: Set(results.map(\.id)))
        return results
    }

    func fetchExtendedWindows(
        base: [WindowInfo],
        screens: ScreenSnapshot,
        includeMinimized: Bool,
        showTabs: Bool,
        currentSpaceOnly: Bool
    ) async -> [WindowInfo] {
        var results = base
        var seenIDs = Set(base.map(\.id))
        let allWindows = (CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []

        if includeMinimized {
            var byWindowID: [CGWindowID: [String: Any]] = [:]
            var byPID: [pid_t: [[String: Any]]] = [:]
            byWindowID.reserveCapacity(allWindows.count)
            for info in allWindows {
                guard let number = info[kCGWindowNumber as String] as? NSNumber,
                      let ownerPID = info[kCGWindowOwnerPID as String] as? NSNumber else { continue }
                byWindowID[CGWindowID(number.uint32Value)] = info
                byPID[pid_t(ownerPID.int32Value), default: []].append(info)
            }

            let currentPID = appsCache.withLock { $0.currentPID }
            let candidatePIDs = NSWorkspace.shared.runningApplications.compactMap { app -> pid_t? in
                guard app.activationPolicy == .regular, app.processIdentifier != currentPID else { return nil }
                return app.processIdentifier
            }

            let collectedMinimized = await Self.collectMinimizedWindows(pids: candidatePIDs)
            appsCache.withLock { apps in
                for minimized in collectedMinimized {
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
                            isMinimized: true,
                            displayIndex: screens.displayIndex(forCoreGraphics: bounds)
                        ),
                        into: &results
                    )
                }
            }
        }

        if showTabs || !currentSpaceOnly {
            var onScreenPIDs = Set(base.map(\.pid))

            appsCache.withLock { apps in
                for info in allWindows {
                    guard let candidate = Candidate(info, minimumSide: 120, apps: &apps) else { continue }
                    if seenIDs.contains(candidate.id) { continue }
                    if candidate.title.isEmpty { continue }
                    if showTabs, currentSpaceOnly, !onScreenPIDs.contains(candidate.pid) { continue }

                    seenIDs.insert(candidate.id)
                    onScreenPIDs.insert(candidate.pid)
                    Self.insertGrouped(candidate.windowInfo(isMinimized: false, screens: screens), into: &results)
                }
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

    private struct AppLookup: Sendable {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        private var names: [pid_t: String?] = [:]

        mutating func name(for pid: pid_t) -> String? {
            if let cached = names[pid] { return cached }
            let app = NSRunningApplication(processIdentifier: pid)
            let resolved = app?.activationPolicy == .regular ? (app?.localizedName ?? "App") : nil
            names[pid] = resolved
            return resolved
        }

        mutating func purge() {
            names.removeAll()
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

        func windowInfo(isMinimized: Bool, screens: ScreenSnapshot) -> WindowInfo {
            WindowInfo(
                id: id,
                pid: pid,
                appName: appName,
                title: title,
                bounds: bounds,
                isMinimized: isMinimized,
                displayIndex: screens.displayIndex(forCoreGraphics: bounds)
            )
        }
    }

    // MARK: - Accessibility

    private struct MinimizedWindow: Sendable {
        let pid: pid_t
        let windowID: CGWindowID
        let title: String
        let bounds: CGRect
    }

    private static func collectMinimizedWindows(pids: [pid_t]) async -> [MinimizedWindow] {
        guard !pids.isEmpty else { return [] }

        return await withTaskGroup(of: [MinimizedWindow].self) { group in
            for pid in pids {
                group.addTask(priority: .userInitiated) { minimizedWindows(pid: pid) }
            }

            var collected: [MinimizedWindow] = []
            for await found in group where !found.isEmpty {
                collected.append(contentsOf: found)
            }
            return collected
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

            let windowID = axWindowID(of: axWindow) ?? 0

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

    private static func resolve(
        _ window: WindowInfo,
        among axWindows: [AXUIElement],
        allowGeometryFallback: Bool
    ) -> AXUIElement? {
        for axWindow in axWindows where axWindowID(of: axWindow) == window.id {
            return axWindow
        }

        if !window.title.isEmpty {
            for axWindow in axWindows {
                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef) == .success,
                   titleRef as? String == window.title {
                    return axWindow
                }
            }
        }

        guard allowGeometryFallback else { return nil }

        var bestMatch: AXUIElement?
        var minDistance: CGFloat = .infinity

        for axWindow in axWindows {
            let frame = axFrame(of: axWindow)
            let dx = frame.origin.x - window.bounds.origin.x
            let dy = frame.origin.y - window.bounds.origin.y
            let dw = frame.size.width - window.bounds.size.width
            let dh = frame.size.height - window.bounds.size.height
            let distance = dx * dx + dy * dy + dw * dw + dh * dh
            if distance < minDistance {
                minDistance = distance
                bestMatch = axWindow
            }
        }

        return minDistance < 10000 ? bestMatch : nil
    }

    private func performOnTargetAXWindow(
        for window: WindowInfo,
        allowGeometryFallback: Bool,
        action: @escaping @Sendable (AXUIElement) -> Void
    ) {
        Task.detached(priority: .userInitiated) {
            let axWindows = Self.axWindows(pid: window.pid, timeout: Self.axActionTimeout)
            guard let target = Self.resolve(
                window,
                among: axWindows,
                allowGeometryFallback: allowGeometryFallback
            ) else { return }
            action(target)
        }
    }

    private static func press(_ buttonAttribute: String, on target: AXUIElement) {
        var buttonRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(target, buttonAttribute as CFString, &buttonRef) == .success,
              let button = buttonRef,
              CFGetTypeID(button) == AXUIElementGetTypeID() else {
            return
        }
        AXUIElementPerformAction(unsafeDowncast(button as AnyObject, to: AXUIElement.self), kAXPressAction as CFString)
    }

    private static func isMinimized(_ target: AXUIElement) -> Bool {
        var minimizedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(target, kAXMinimizedAttribute as CFString, &minimizedRef) == .success else {
            return false
        }
        return (minimizedRef as? NSNumber)?.boolValue == true
    }

    private static func setFrame(_ frame: CGRect, on target: AXUIElement) {
        var origin = frame.origin
        var size = frame.size
        if let positionValue = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(target, kAXPositionAttribute as CFString, positionValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(target, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    // MARK: - Actions

    func focus(window: WindowInfo) {
        guard let app = NSRunningApplication(processIdentifier: window.pid) else { return }
        if app.isHidden { app.unhide() }
        app.activate()

        performOnTargetAXWindow(for: window, allowGeometryFallback: true) { target in
            if Self.isMinimized(target) {
                AXUIElementSetAttributeValue(target, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            }
            AXUIElementSetAttributeValue(target, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(target, kAXRaiseAction as CFString)
        }
    }

    func quitApplication(pid: pid_t) {
        NSRunningApplication(processIdentifier: pid)?.terminate()
    }

    func hideApplication(pid: pid_t) {
        NSRunningApplication(processIdentifier: pid)?.hide()
    }

    func close(window: WindowInfo) {
        performOnTargetAXWindow(for: window, allowGeometryFallback: false) { target in
            Self.press(kAXCloseButtonAttribute, on: target)
        }
    }

    func toggleMinimize(window: WindowInfo) {
        performOnTargetAXWindow(for: window, allowGeometryFallback: false) { target in
            let minimized = Self.isMinimized(target)
            AXUIElementSetAttributeValue(
                target,
                kAXMinimizedAttribute as CFString,
                minimized ? kCFBooleanFalse : kCFBooleanTrue
            )
        }
    }

    func toggleZoom(window: WindowInfo) {
        performOnTargetAXWindow(for: window, allowGeometryFallback: false) { target in
            Self.press(kAXZoomButtonAttribute, on: target)
        }
    }

    func tile(window: WindowInfo, side: TileSide, screens: ScreenSnapshot) {
        let index = screens.screenIndex(containingCoreGraphics: window.bounds) ?? 0
        guard let visible = screens.visibleFrame(at: index) else { return }

        let half = CGRect(
            x: side == .left ? visible.minX : visible.midX,
            y: visible.minY,
            width: (visible.width / 2).rounded(.down),
            height: visible.height
        )
        let target = screens.coreGraphicsRect(fromAppKit: half).integral

        performOnTargetAXWindow(for: window, allowGeometryFallback: false) { element in
            if Self.isMinimized(element) {
                AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            }
            Self.setFrame(target, on: element)
        }
    }

    func moveToNextDisplay(window: WindowInfo, screens: ScreenSnapshot) {
        guard screens.count > 1 else { return }
        let currentIndex = screens.screenIndex(containingCoreGraphics: window.bounds) ?? 0
        let nextIndex = (currentIndex + 1) % screens.count
        guard let current = screens.visibleFrame(at: currentIndex),
              let next = screens.visibleFrame(at: nextIndex) else { return }

        let appKitBounds = screens.appKitRect(fromCoreGraphics: window.bounds)
        let relativeX = current.width > 0 ? (appKitBounds.minX - current.minX) / current.width : 0
        let relativeY = current.height > 0 ? (appKitBounds.minY - current.minY) / current.height : 0

        let width = min(appKitBounds.width, next.width)
        let height = min(appKitBounds.height, next.height)
        let x = min(max(next.minX, next.minX + relativeX * next.width), next.maxX - width)
        let y = min(max(next.minY, next.minY + relativeY * next.height), next.maxY - height)

        let target = screens
            .coreGraphicsRect(fromAppKit: CGRect(x: x, y: y, width: width, height: height))
            .integral

        performOnTargetAXWindow(for: window, allowGeometryFallback: false) { element in
            Self.setFrame(target, on: element)
        }
    }

    // MARK: - Thumbnails

    private func shareableWindows() async -> [CGWindowID: SCWindow]? {
        let now = ContinuousClock.now
        let cached = shareable.withLock { cache -> [CGWindowID: SCWindow]? in
            guard let fetchedAt = cache.fetchedAt,
                  now - fetchedAt < Self.shareableContentLifetime,
                  let windows = cache.windows else { return nil }
            return windows.value
        }
        if let cached { return cached }

        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) else {
            return nil
        }

        var map: [CGWindowID: SCWindow] = [:]
        map.reserveCapacity(content.windows.count)
        for window in content.windows { map[window.windowID] = window }

        shareable.withLock { cache in
            cache.windows = Unchecked(map)
            cache.fetchedAt = ContinuousClock.now
        }
        return map
    }

    func captureThumbnails(
        for windows: [WindowInfo],
        priorityID: CGWindowID?,
        onCapture: @escaping @Sendable @MainActor (CGWindowID, CGImage) -> Void
    ) async {
        guard !windows.isEmpty, !Task.isCancelled, let scWindows = await shareableWindows(), !Task.isCancelled else {
            return
        }

        let now = ContinuousClock.now
        var ordered = windows.filter { scWindows[$0.id] != nil && !isFresh($0, now: now) }
        if let priorityID, let index = ordered.firstIndex(where: { $0.id == priorityID }) {
            ordered.insert(ordered.remove(at: index), at: 0)
        }
        guard !ordered.isEmpty else { return }

        await withTaskGroup(of: (CGWindowID, CGImage)?.self) { group in
            var next = 0
            let inFlight = min(Self.maxConcurrentCaptures, ordered.count)

            func schedule() {
                guard next < ordered.count, !Task.isCancelled else { return }
                let window = ordered[next]
                next += 1
                guard let match = scWindows[window.id] else { return }
                let scWindow = Unchecked(match)
                group.addTask { [self] in
                    guard !Task.isCancelled else { return nil }
                    guard let image = await capture(scWindow.value, window: window) else { return nil }
                    guard !Task.isCancelled else { return nil }
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

    private func capture(_ scWindow: SCWindow, window: WindowInfo) async -> CGImage? {
        let configuration = SCStreamConfiguration()
        let (width, height) = Self.thumbnailPixelSize(for: window.bounds)
        configuration.width = width
        configuration.height = height
        configuration.showsCursor = false
        configuration.scalesToFit = true
        configuration.ignoreShadowsSingleWindow = true
        configuration.pixelFormat = kCVPixelFormatType_32BGRA

        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        guard let image = try? await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        ) else {
            return nil
        }
        store(image, for: scWindow.windowID, bounds: window.bounds)
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
