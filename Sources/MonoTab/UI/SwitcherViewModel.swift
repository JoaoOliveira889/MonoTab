import CoreGraphics
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ThumbnailSlot {
    var image: CGImage?

    init(image: CGImage? = nil) {
        self.image = image
    }
}

private struct RankedWindow {
    let window: WindowInfo
    let score: Int
    let order: Int
}

@MainActor
@Observable
final class SwitcherViewModel {
    var windows: [WindowInfo] = [] {
        didSet { applyFilter() }
    }

    private(set) var filteredWindows: [WindowInfo] = []

    var searchQuery: String = "" {
        didSet {
            guard searchQuery != oldValue else { return }
            applyFilter()
            selectedIndex = 0
        }
    }

    var selectedIndex: Int = 0

    var maxGridHeight: CGFloat = 640

    var isSearchMode: Bool = false {
        didSet {
            guard isSearchMode != oldValue else { return }
            onOverlayStateChange?()
        }
    }

    var isSettingsOpen: Bool = false {
        didSet {
            guard isSettingsOpen != oldValue else { return }
            onOverlayStateChange?()
        }
    }

    @ObservationIgnored var onOverlayStateChange: (@MainActor () -> Void)?
    @ObservationIgnored private var slots: [CGWindowID: ThumbnailSlot] = [:]
    @ObservationIgnored private var extendedFetchTask: Task<Void, Never>?
    @ObservationIgnored private var thumbnailTask: Task<Void, Never>?

    init() {}

    var selectedWindow: WindowInfo? {
        filteredWindows.indices.contains(selectedIndex) ? filteredWindows[selectedIndex] : nil
    }

    func slot(for windowID: CGWindowID) -> ThumbnailSlot {
        if let existing = slots[windowID] { return existing }
        let slot = ThumbnailSlot(image: WindowManager.shared.cachedThumbnail(for: windowID))
        slots[windowID] = slot
        return slot
    }

    private func applyFilter() {
        let query = WindowInfo.normalize(searchQuery)
        guard !query.isEmpty else {
            filteredWindows = windows
            return
        }

        var ranked: [RankedWindow] = []
        ranked.reserveCapacity(windows.count)
        for (index, window) in windows.enumerated() {
            guard let score = window.matchScore(normalizedQuery: query) else { continue }
            ranked.append(RankedWindow(window: window, score: score, order: index))
        }
        ranked.sort { $0.score == $1.score ? $0.order < $1.order : $0.score > $1.score }
        filteredWindows = ranked.map(\.window)
    }

    func refreshWindows() {
        extendedFetchTask?.cancel()
        searchQuery = ""
        isSearchMode = false
        isSettingsOpen = false

        let preferences = PreferencesManager.shared
        let includeMinimized = preferences.showMinimizedWindows
        let showTabs = preferences.showAppTabs
        let currentSpaceOnly = preferences.currentSpaceOnly

        let base = WindowManager.shared.fetchOnScreenWindows()
        apply(windows: base, preferredID: nil)

        guard includeMinimized || showTabs || !currentSpaceOnly else { return }

        let preferredID = selectedWindow?.id
        extendedFetchTask = Task { [weak self] in
            let extended = await WindowManager.shared.fetchExtendedWindows(
                base: base,
                includeMinimized: includeMinimized,
                showTabs: showTabs,
                currentSpaceOnly: currentSpaceOnly
            )
            guard !Task.isCancelled, let self, extended.count != base.count else { return }
            self.apply(windows: extended, preferredID: preferredID)
        }
    }

    private func apply(windows newWindows: [WindowInfo], preferredID: CGWindowID?) {
        windows = newWindows

        let liveIDs = Set(newWindows.map(\.id))
        slots = slots.filter { liveIDs.contains($0.key) }
        AppIconCache.retain(pids: Set(newWindows.map(\.pid)))

        if let preferredID, let index = filteredWindows.firstIndex(where: { $0.id == preferredID }) {
            selectedIndex = index
        } else {
            selectedIndex = filteredWindows.count > 1 ? 1 : 0
        }

        startThumbnailCapture()
    }

    private func startThumbnailCapture() {
        thumbnailTask?.cancel()
        guard PermissionsManager.shared.hasScreenRecording, !windows.isEmpty else { return }

        let targets = windows
        let priorityID = selectedWindow?.id
        thumbnailTask = Task { [weak self] in
            await WindowManager.shared.captureThumbnails(for: targets, priorityID: priorityID) { id, image in
                self?.slot(for: id).image = image
            }
        }
    }

    func cancelPendingWork() {
        extendedFetchTask?.cancel()
        thumbnailTask?.cancel()
        extendedFetchTask = nil
        thumbnailTask = nil
    }

    func select(id: CGWindowID) {
        guard let index = filteredWindows.firstIndex(where: { $0.id == id }) else { return }
        selectedIndex = index
    }

    func selectNext() {
        let count = filteredWindows.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + 1) % count
    }

    func selectPrevious() {
        let count = filteredWindows.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex - 1 + count) % count
    }

    func navigate(direction: HotkeyManager.NavigationDirection, columns: Int) {
        let count = filteredWindows.count
        guard count > 0 else { return }

        switch direction {
        case .left:
            selectPrevious()
        case .right:
            selectNext()
        case .up:
            let target = selectedIndex - columns
            if target >= 0 { selectedIndex = target }
        case .down:
            let target = selectedIndex + columns
            if target < count { selectedIndex = target }
        }
    }

    private func mutateWindows(_ mutation: () -> Void) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
            mutation()
            clampSelection()
        }
    }

    func removeWindows(pid: pid_t) {
        mutateWindows {
            for window in windows where window.pid == pid {
                slots.removeValue(forKey: window.id)
            }
            windows.removeAll { $0.pid == pid }
        }
    }

    func removeWindow(id: CGWindowID) {
        mutateWindows {
            windows.removeAll { $0.id == id }
            slots.removeValue(forKey: id)
        }
    }

    private func clampSelection() {
        let remaining = filteredWindows.count
        selectedIndex = remaining == 0 ? 0 : min(selectedIndex, remaining - 1)
    }

    func columnCount(isFullscreen: Bool) -> Int {
        let count = filteredWindows.count
        switch count {
        case ...2: return max(1, count)
        case ...4: return count
        case ...8: return isFullscreen ? min(5, count) : min(4, max(2, (count + 1) / 2))
        case ...14: return isFullscreen ? 6 : 5
        default: return isFullscreen ? 7 : 5
        }
    }

    func enterSearchMode() {
        isSearchMode = true
    }

    func exitSearchMode() {
        isSearchMode = false
        searchQuery = ""
    }

    func openSettings() {
        isSettingsOpen = true
    }

    func closeSettings() {
        isSettingsOpen = false
    }

    func toggleSettings() {
        isSettingsOpen.toggle()
    }
}
