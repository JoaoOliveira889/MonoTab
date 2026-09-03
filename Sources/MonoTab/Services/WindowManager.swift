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

    /// Fetches all active windows from running standard applications, optionally including minimized windows.
    public func fetchActiveWindows(includeMinimized: Bool = false) -> [WindowInfo] {
        let options: CGWindowListOption = includeMinimized
            ? [.excludeDesktopElements]
            : [.optionOnScreenOnly, .excludeDesktopElements]

        guard let windowListInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        var results: [WindowInfo] = []
        var seenIDs = Set<CGWindowID>()
        var appCache: [pid_t: (name: String, icon: NSImage?)] = [:]

        for info in windowListInfo {
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
            let isOnScreen = (info[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? true
            let isMinimized = !isOnScreen

            let item = WindowInfo(
                id: windowID,
                pid: pid,
                appName: appName,
                title: windowTitle,
                bounds: bounds,
                layer: layer,
                appIcon: icon,
                isMinimized: isMinimized
            )

            seenIDs.insert(windowID)
            results.append(item)
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
}
