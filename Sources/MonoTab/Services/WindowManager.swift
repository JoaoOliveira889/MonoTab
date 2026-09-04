import AppKit
import ApplicationServices
import Foundation
import ScreenCaptureKit

public final class WindowManager: @unchecked Sendable {
    public static let shared = WindowManager()

    /// Thread-safe in-memory cache for window thumbnails.
    /// Strictly RAM-only; zero disk caching for absolute privacy.
    private final class FastThumbnailCache: @unchecked Sendable {
        private var storage: [CGWindowID: (image: NSImage, date: Date)] = [:]
        private let lock = NSLock()

        func get(for id: CGWindowID) -> NSImage? {
            lock.lock()
            defer { lock.unlock() }
            return storage[id]?.image
        }

        func set(_ image: NSImage, for id: CGWindowID) {
            lock.lock()
            storage[id] = (image, Date())
            if storage.count > 60 {
                let oldestKeys = storage.sorted { $0.value.date < $1.value.date }.prefix(20).map(\.key)
                for key in oldestKeys { storage.removeValue(forKey: key) }
            }
            lock.unlock()
        }

        /// Purges closed windows from RAM
        func purgeMissing(existingIDs: Set<CGWindowID>) {
            lock.lock()
            defer { lock.unlock() }
            storage = storage.filter { existingIDs.contains($0.key) }
        }

        func clear() {
            lock.lock()
            defer { lock.unlock() }
            storage.removeAll()
        }
    }

    private let cache = FastThumbnailCache()

    private init() {}

    public func cachedThumbnail(for windowID: CGWindowID) -> NSImage? {
        cache.get(for: windowID)
    }

    public func clearCache() {
        cache.clear()
    }

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

    /// Fetches all active windows from running standard applications, optionally including minimized windows, tabs, and other spaces.
    public func fetchActiveWindows(
        includeMinimized: Bool = false,
        showTabs: Bool = false,
        currentSpaceOnly: Bool = true
    ) -> [WindowInfo] {
        // Step 1: Always retrieve on-screen windows from the current desktop space
        let onScreenOptions: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let onScreenList = CGWindowListCopyWindowInfo(onScreenOptions, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        var results: [WindowInfo] = []
        var seenIDs = Set<CGWindowID>()
        var appCache: [pid_t: (name: String, icon: NSImage?)] = [:]

        for info in onScreenList {
            guard let windowNumber = info[kCGWindowNumber as String] as? NSNumber else { continue }
            let windowID = CGWindowID(windowNumber.uint32Value)
            if seenIDs.contains(windowID) { continue }

            guard let pidNumber = info[kCGWindowOwnerPID as String] as? NSNumber else { continue }
            let pid = pid_t(pidNumber.int32Value)
            if pid == currentPID { continue }

            let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? -1
            if layer != 0 { continue }

            let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1.0
            if alpha < 0.05 { continue }

            guard let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict) else {
                continue
            }
            if bounds.width < 60 || bounds.height < 60 || bounds.origin.x < -2000 {
                continue
            }

            let appName: String
            let icon: NSImage?

            if let cachedApp = appCache[pid] {
                appName = cachedApp.name
                icon = cachedApp.icon
            } else {
                guard let app = NSRunningApplication(processIdentifier: pid),
                      app.activationPolicy == .regular else {
                    continue
                }
                let resolvedName = (info[kCGWindowOwnerName as String] as? String) ?? app.localizedName ?? "App"
                let resolvedIcon = app.icon
                appCache[pid] = (resolvedName, resolvedIcon)
                appName = resolvedName
                icon = resolvedIcon
            }

            let windowTitle = (info[kCGWindowName as String] as? String) ?? ""
            let trimmedTitle = windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)

            // Exclude windows explicitly marked offscreen
            if let isOnscreen = info[kCGWindowIsOnscreen as String] as? Bool, !isOnscreen {
                continue
            }

            // Filter out auxiliary, ghost, or backdrop windows with empty titles (especially for Safari and browsers)
            let isBrowserOrDocApp = appName.localizedCaseInsensitiveContains("Safari") ||
                                    appName.localizedCaseInsensitiveContains("Chrome") ||
                                    appName.localizedCaseInsensitiveContains("Arc") ||
                                    appName.localizedCaseInsensitiveContains("Firefox") ||
                                    appName.localizedCaseInsensitiveContains("Brave") ||
                                    appName.localizedCaseInsensitiveContains("Edge")
            if isBrowserOrDocApp && trimmedTitle.isEmpty {
                continue
            }

            let item = WindowInfo(
                id: windowID,
                pid: pid,
                appName: appName,
                title: windowTitle,
                bounds: bounds,
                layer: layer,
                appIcon: icon,
                isMinimized: false
            )

            seenIDs.insert(windowID)
            results.append(item)
        }

        // Full system window list cache if needed for minimized windows, tabs, or all spaces
        var allWindowsList: [[String: Any]] = []
        var windowDict: [CGWindowID: [String: Any]] = [:]
        var pidWindows: [pid_t: [[String: Any]]] = [:]

        func ensureAllWindowsLoaded() {
            guard allWindowsList.isEmpty else { return }
            allWindowsList = (CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
            for winInfo in allWindowsList {
                if let num = winInfo[kCGWindowNumber as String] as? NSNumber {
                    let wid = CGWindowID(num.uint32Value)
                    windowDict[wid] = winInfo
                    if let pidNum = winInfo[kCGWindowOwnerPID as String] as? NSNumber {
                        pidWindows[pid_t(pidNum.int32Value), default: []].append(winInfo)
                    }
                }
            }
        }

        // Step 2: Include truly minimized windows from running apps via Accessibility API
        if includeMinimized {
            ensureAllWindowsLoaded()

            let regularApps = NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy == .regular && $0.processIdentifier != currentPID
            }

            for app in regularApps {
                let pid = app.processIdentifier
                let appElement = AXUIElementCreateApplication(pid)
                AXUIElementSetMessagingTimeout(appElement, 0.05) // Non-blocking: max 50ms per app

                var windowsRef: CFTypeRef?
                guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                      let axWindows = windowsRef as? [AXUIElement] else {
                    continue
                }

                for axWin in axWindows {
                    var minRef: CFTypeRef?
                    guard AXUIElementCopyAttributeValue(axWin, kAXMinimizedAttribute as CFString, &minRef) == .success,
                          let isMin = minRef as? NSNumber, isMin.boolValue else {
                        continue
                    }

                    // Window is confirmed minimized to the Dock
                    var winID: CGWindowID = 0
                    let axErr = _AXUIElementGetWindow(axWin, &winID)

                    var titleRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(axWin, kAXTitleAttribute as CFString, &titleRef)
                    let axTitle = (titleRef as? String) ?? ""

                    var matchedInfo: [String: Any]?
                    if axErr == .success && winID > 0 {
                        matchedInfo = windowDict[winID]
                    }

                    // Fallback matching if _AXUIElementGetWindow returned 0
                    if matchedInfo == nil {
                        if let candidates = pidWindows[pid] {
                            matchedInfo = candidates.first(where: { info in
                                guard let num = info[kCGWindowNumber as String] as? NSNumber else { return false }
                                let id = CGWindowID(num.uint32Value)
                                if seenIDs.contains(id) { return false }
                                let name = (info[kCGWindowName as String] as? String) ?? ""
                                return !axTitle.isEmpty && name == axTitle
                            }) ?? candidates.first(where: { info in
                                guard let num = info[kCGWindowNumber as String] as? NSNumber else { return false }
                                let id = CGWindowID(num.uint32Value)
                                return !seenIDs.contains(id)
                            })

                            if let found = matchedInfo, let num = found[kCGWindowNumber as String] as? NSNumber {
                                winID = CGWindowID(num.uint32Value)
                            }
                        }
                    }

                    guard winID > 0, !seenIDs.contains(winID) else { continue }

                    var bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
                    if let info = matchedInfo,
                       let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                       let b = CGRect(dictionaryRepresentation: boundsDict) {
                        bounds = b
                    } else {
                        var posValue: CFTypeRef?
                        var sizeValue: CFTypeRef?
                        var pos = CGPoint.zero
                        var size = CGSize(width: 800, height: 600)
                        if AXUIElementCopyAttributeValue(axWin, kAXPositionAttribute as CFString, &posValue) == .success,
                           let pv = posValue, CFGetTypeID(pv) == AXValueGetTypeID() {
                            AXValueGetValue((pv as! AXValue), .cgPoint, &pos)
                        }
                        if AXUIElementCopyAttributeValue(axWin, kAXSizeAttribute as CFString, &sizeValue) == .success,
                           let sv = sizeValue, CFGetTypeID(sv) == AXValueGetTypeID() {
                            AXValueGetValue((sv as! AXValue), .cgSize, &size)
                        }
                        bounds = CGRect(origin: pos, size: size)
                    }

                    let appName = (matchedInfo?[kCGWindowOwnerName as String] as? String) ?? app.localizedName ?? "App"
                    let finalTitle = !axTitle.isEmpty ? axTitle : ((matchedInfo?[kCGWindowName as String] as? String) ?? "")

                    let item = WindowInfo(
                        id: winID,
                        pid: pid,
                        appName: appName,
                        title: finalTitle,
                        bounds: bounds,
                        layer: 0,
                        appIcon: app.icon,
                        isMinimized: true
                    )

                    seenIDs.insert(winID)

                    // Keep minimized windows grouped adjacent to active windows of the same app
                    if let lastAppIndex = results.lastIndex(where: { $0.pid == pid }) {
                        results.insert(item, at: lastAppIndex + 1)
                    } else {
                        results.append(item)
                    }
                }
            }
        }

        // Step 3: Optional tab inclusion or other spaces inclusion
        if showTabs || !currentSpaceOnly {
            ensureAllWindowsLoaded()

            for info in allWindowsList {
                guard let windowNumber = info[kCGWindowNumber as String] as? NSNumber else { continue }
                let windowID = CGWindowID(windowNumber.uint32Value)
                if seenIDs.contains(windowID) { continue }

                guard let pidNumber = info[kCGWindowOwnerPID as String] as? NSNumber else { continue }
                let pid = pid_t(pidNumber.int32Value)
                if pid == currentPID { continue }

                let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? -1
                if layer != 0 { continue }

                let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1.0
                if alpha < 0.05 { continue }

                guard let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                      let bounds = CGRect(dictionaryRepresentation: boundsDict) else {
                    continue
                }
                if bounds.width < 120 || bounds.height < 120 || bounds.origin.x < -2000 {
                    continue
                }

                // If only showTabs is enabled (but currentSpaceOnly is true), only accept tabs from apps already on-screen
                let isAppOnScreen = results.contains(where: { $0.pid == pid })
                if showTabs && currentSpaceOnly && !isAppOnScreen {
                    continue
                }

                guard let app = NSRunningApplication(processIdentifier: pid),
                      app.activationPolicy == .regular else {
                    continue
                }

                let appName = (info[kCGWindowOwnerName as String] as? String) ?? app.localizedName ?? "App"
                let windowTitle = (info[kCGWindowName as String] as? String) ?? ""

                // Filter out headless or empty title offscreen utility windows
                if windowTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }

                let item = WindowInfo(
                    id: windowID,
                    pid: pid,
                    appName: appName,
                    title: windowTitle,
                    bounds: bounds,
                    layer: layer,
                    appIcon: app.icon,
                    isMinimized: false
                )

                seenIDs.insert(windowID)
                if let lastAppIndex = results.lastIndex(where: { $0.pid == pid }) {
                    results.insert(item, at: lastAppIndex + 1)
                } else {
                    results.append(item)
                }
            }
        }

        // Automatic memory cleanup: purge closed windows from cache
        cache.purgeMissing(existingIDs: seenIDs)

        return results
    }

    /// Captures a crisp thumbnail using Apple's high-performance ScreenCaptureKit.
    public func captureThumbnail(for windowID: CGWindowID, from window: SCWindow? = nil) async -> NSImage? {
        do {
            let scWindow: SCWindow
            if let direct = window {
                scWindow = direct
            } else {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let found = content.windows.first(where: { $0.windowID == windowID }) else {
                    return nil
                }
                scWindow = found
            }

            let config = SCStreamConfiguration()
            config.width = 460
            config.height = 280
            config.showsCursor = false
            config.scalesToFit = true
            config.pixelFormat = kCVPixelFormatType_32BGRA

            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            cache.set(image, for: windowID)
            return image
        } catch {
            return nil
        }
    }

    /// Brings the target application and window smoothly into the foreground.
    public func focus(window: WindowInfo) {
        guard let app = NSRunningApplication(processIdentifier: window.pid) else { return }

        if app.isHidden {
            app.unhide()
        }

        app.activate()

        let appElement = AXUIElementCreateApplication(window.pid)
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)

        if result == .success, let axWindows = windowsValue as? [AXUIElement] {
            var bestMatch: AXUIElement?

            for axWin in axWindows {
                var titleValue: CFTypeRef?
                let titleRes = AXUIElementCopyAttributeValue(axWin, kAXTitleAttribute as CFString, &titleValue)
                let axTitle = (titleRes == .success ? titleValue as? String : nil) ?? ""

                var posValue: CFTypeRef?
                var sizeValue: CFTypeRef?
                var pos = CGPoint.zero
                var size = CGSize.zero

                if AXUIElementCopyAttributeValue(axWin, kAXPositionAttribute as CFString, &posValue) == .success,
                   let pv = posValue, CFGetTypeID(pv) == AXValueGetTypeID() {
                    AXValueGetValue((pv as! AXValue), .cgPoint, &pos)
                }
                if AXUIElementCopyAttributeValue(axWin, kAXSizeAttribute as CFString, &sizeValue) == .success,
                   let sv = sizeValue, CFGetTypeID(sv) == AXValueGetTypeID() {
                    AXValueGetValue((sv as! AXValue), .cgSize, &size)
                }

                if !window.title.isEmpty && axTitle == window.title {
                    bestMatch = axWin
                    break
                }

                let posDiff = abs(pos.x - window.bounds.origin.x) + abs(pos.y - window.bounds.origin.y)
                let sizeDiff = abs(size.width - window.bounds.size.width) + abs(size.height - window.bounds.size.height)
                if posDiff < 30 && sizeDiff < 30 {
                    bestMatch = axWin
                    break
                }
            }

            let target = bestMatch ?? axWindows.first
            if let target = target {
                // If the target window is minimized, unminimize/restore it
                var minVal: CFTypeRef?
                if AXUIElementCopyAttributeValue(target, kAXMinimizedAttribute as CFString, &minVal) == .success,
                   let isMin = minVal as? NSNumber, isMin.boolValue {
                    AXUIElementSetAttributeValue(target, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                }

                AXUIElementSetAttributeValue(target, kAXMainAttribute as CFString, kCFBooleanTrue)
                AXUIElementPerformAction(target, kAXRaiseAction as CFString)
            }
        }
    }

    /// Closes the specified window smoothly via macOS Accessibility API
    public func close(window: WindowInfo) {
        let appElement = AXUIElementCreateApplication(window.pid)
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)

        guard result == .success, let axWindows = windowsValue as? [AXUIElement] else {
            return
        }

        var targetWindow: AXUIElement?

        // Match by CGWindowID first
        for axWin in axWindows {
            var winID: CGWindowID = 0
            if _AXUIElementGetWindow(axWin, &winID) == .success && winID == window.id {
                targetWindow = axWin
                break
            }
        }

        // Fallback: match by title and bounds
        if targetWindow == nil {
            for axWin in axWindows {
                var titleValue: CFTypeRef?
                let titleRes = AXUIElementCopyAttributeValue(axWin, kAXTitleAttribute as CFString, &titleValue)
                let axTitle = (titleRes == .success ? titleValue as? String : nil) ?? ""

                if !window.title.isEmpty && axTitle == window.title {
                    targetWindow = axWin
                    break
                }
            }
        }

        guard let target = targetWindow ?? axWindows.first else { return }

        // Find the close button and press it
        var closeButtonValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(target, kAXCloseButtonAttribute as CFString, &closeButtonValue) == .success,
           let closeBtn = closeButtonValue {
            _ = AXUIElementPerformAction(closeBtn as! AXUIElement, kAXPressAction as CFString)
        }
    }
}
