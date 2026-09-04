import AppKit
import Combine
import Foundation
import ScreenCaptureKit
import SwiftUI

@MainActor
public final class SwitcherViewModel: ObservableObject {
    @Published public var windows: [WindowInfo] = []
    @Published public var isSearchMode: Bool = false
    @Published public var isSettingsOpen: Bool = false
    @Published public var searchQuery: String = "" {
        didSet {
            selectedIndex = 0
        }
    }
    @Published public var selectedIndex: Int = 0
    @Published public var thumbnails: [CGWindowID: NSImage] = [:]

    private var thumbnailTask: Task<Void, Never>?

    public init() {}

    public var filteredWindows: [WindowInfo] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return windows
        }
        return windows.filter { $0.matches(query: trimmed) }
    }

    public var selectedWindow: WindowInfo? {
        let list = filteredWindows
        guard selectedIndex >= 0 && selectedIndex < list.count else { return nil }
        return list[selectedIndex]
    }

    public func refreshWindows() {
        thumbnailTask?.cancel()
        searchQuery = ""
        isSearchMode = false
        isSettingsOpen = false

        let showMinimized = PreferencesManager.shared.showMinimizedWindows
        let showTabs = PreferencesManager.shared.showAppTabs
        let currentSpaceOnly = PreferencesManager.shared.currentSpaceOnly
        let activeWindows = WindowManager.shared.fetchActiveWindows(
            includeMinimized: showMinimized,
            showTabs: showTabs,
            currentSpaceOnly: currentSpaceOnly
        )
        self.windows = activeWindows

        // Preload any cached thumbnails instantly
        var preloaded: [CGWindowID: NSImage] = [:]
        for window in activeWindows {
            if let cached = WindowManager.shared.cachedThumbnail(for: window.id) {
                preloaded[window.id] = cached
            }
        }
        self.thumbnails = preloaded

        // Default selection: switch to the previous app (index 1) if available
        let initialIndex = activeWindows.count > 1 ? 1 : 0
        self.selectedIndex = initialIndex

        // Start progressive, streaming thumbnail capture
        loadThumbnailsProgressively(for: activeWindows, prioritizedIndex: initialIndex)
    }

    private func loadThumbnailsProgressively(for windowList: [WindowInfo], prioritizedIndex: Int) {
        guard PermissionsManager.shared.hasScreenRecording, !windowList.isEmpty else { return }

        var prioritizedIDs = windowList.map(\.id)
        if prioritizedIndex < prioritizedIDs.count {
            let prioritized = prioritizedIDs.remove(at: prioritizedIndex)
            prioritizedIDs.insert(prioritized, at: 0)
        }

        thumbnailTask = Task { [weak self] in
            guard let shareable = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) else {
                return
            }
            let scWindows = shareable.windows
            guard !scWindows.isEmpty, !Task.isCancelled else { return }

            var windowMap: [CGWindowID: SCWindow] = [:]
            for win in scWindows {
                windowMap[win.windowID] = win
            }

            for winID in prioritizedIDs {
                if Task.isCancelled { break }
                guard let self = self else { break }
                guard let scWin = windowMap[winID] else { continue }

                if let thumb = await WindowManager.shared.captureThumbnail(for: winID, from: scWin) {
                    if !Task.isCancelled {
                        self.thumbnails[winID] = thumb
                    }
                }

                // Cooperative pause to avoid CPU/GPU contention with the UI animations
                try? await Task.sleep(for: .milliseconds(10))
            }
        }
    }

    public func removeWindow(id: CGWindowID) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
            windows.removeAll { $0.id == id }
            thumbnails.removeValue(forKey: id)
            let remaining = filteredWindows.count
            if remaining == 0 {
                selectedIndex = 0
            } else if selectedIndex >= remaining {
                selectedIndex = max(0, remaining - 1)
            }
        }
    }

    public func selectNext() {
        let count = filteredWindows.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + 1) % count
    }

    public func selectPrevious() {
        let count = filteredWindows.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex - 1 + count) % count
    }

    public func columnCount(isFullscreen: Bool) -> Int {
        let count = filteredWindows.count
        if count <= 2 {
            return max(1, count)
        } else if count <= 4 {
            return min(4, count)
        } else if count <= 8 {
            return isFullscreen ? min(5, max(3, count)) : min(4, max(2, (count + 1) / 2))
        } else if count <= 14 {
            return isFullscreen ? 6 : 5
        } else {
            return isFullscreen ? 7 : 5
        }
    }

    public func navigate(direction: HotkeyManager.NavigationDirection, columns: Int) {
        let count = filteredWindows.count
        guard count > 0 else { return }

        switch direction {
        case .left:
            selectPrevious()
        case .right:
            selectNext()
        case .up:
            let target = selectedIndex - columns
            selectedIndex = target >= 0 ? target : selectedIndex
        case .down:
            let target = selectedIndex + columns
            selectedIndex = target < count ? target : selectedIndex
        }
    }

    public func enterSearchMode() {
        isSearchMode = true
    }

    public func exitSearchMode() {
        isSearchMode = false
        searchQuery = ""
    }

    public func openSettings() {
        isSettingsOpen = true
    }

    public func closeSettings() {
        isSettingsOpen = false
    }

    public func toggleSettings() {
        isSettingsOpen.toggle()
    }
}
