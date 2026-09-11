import CoreGraphics
import Foundation
import Observation
import SwiftUI

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

@Observable
final class SwitcherViewModel {
    var windows: [WindowInfo] = [] {
        didSet {
            searchKeys = nil
            syncSlots()
            applyFilter()
        }
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
    var isAppOnlyMode: Bool = false
    var isPreviewOpen: Bool = false
    var pendingConfirmation: PendingConfirmation?

    @ObservationIgnored var targetAppPID: pid_t?

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

    var isHelpOpen: Bool = false

    var isTextEntryActive: Bool { isSearchMode || isSettingsOpen }

    var coversWholeScreen: Bool {
        PreferencesManager.shared.displayMode == .fullscreen
    }

    @ObservationIgnored var onOverlayStateChange: (@MainActor () -> Void)?
    @ObservationIgnored private var slots: [CGWindowID: ThumbnailSlot] = [:]
    @ObservationIgnored private var searchKeys: [WindowSearchKey]?
    @ObservationIgnored private var extendedFetchTask: Task<Void, Never>?
    @ObservationIgnored private var thumbnailTask: Task<Void, Never>?

    init() {}

    var selectedWindow: WindowInfo? {
        filteredWindows.indices.contains(selectedIndex) ? filteredWindows[selectedIndex] : nil
    }

    func slot(for windowID: CGWindowID) -> ThumbnailSlot {
        slots[windowID] ?? ThumbnailSlot(image: WindowManager.shared.cachedThumbnail(for: windowID))
    }

    func quickNumbers() -> [CGWindowID: Int] {
        guard PreferencesManager.shared.showQuickShortcuts else { return [:] }
        var numbers: [CGWindowID: Int] = [:]
        for (index, window) in filteredWindows.prefix(9).enumerated() {
            numbers[window.id] = index + 1
        }
        return numbers
    }

    private func syncSlots() {
        var updated: [CGWindowID: ThumbnailSlot] = [:]
        updated.reserveCapacity(windows.count)
        for window in windows {
            updated[window.id] = slots[window.id]
                ?? ThumbnailSlot(image: WindowManager.shared.cachedThumbnail(for: window.id))
        }
        slots = updated
    }

    private func resolvedSearchKeys() -> [WindowSearchKey] {
        if let searchKeys { return searchKeys }
        let keys = windows.map(\.searchKey)
        searchKeys = keys
        return keys
    }

    private func applyFilter() {
        let query = WindowInfo.normalize(searchQuery)
        guard !query.isEmpty else {
            filteredWindows = windows
            return
        }

        let keys = resolvedSearchKeys()
        var ranked: [RankedWindow] = []
        ranked.reserveCapacity(windows.count)
        for (index, window) in windows.enumerated() {
            guard index < keys.count, let score = keys[index].score(query: query) else { continue }
            ranked.append(RankedWindow(window: window, score: score, order: index))
        }
        ranked.sort { $0.score == $1.score ? $0.order < $1.order : $0.score > $1.score }
        filteredWindows = ranked.map(\.window)
    }

    // MARK: - Refresh

    func refreshWindows(appOnly: Bool = false, targetPID: pid_t? = nil, screens: ScreenSnapshot) {
        extendedFetchTask?.cancel()
        searchQuery = ""
        isSearchMode = false
        isSettingsOpen = false
        isHelpOpen = false
        isPreviewOpen = false
        pendingConfirmation = nil
        isAppOnlyMode = appOnly
        targetAppPID = targetPID

        let preferences = PreferencesManager.shared
        let includeMinimized = preferences.showMinimizedWindows
        let showTabs = preferences.showAppTabs
        let currentSpaceOnly = preferences.currentSpaceOnly

        var base = WindowManager.shared.fetchOnScreenWindows(screens: screens)
        if appOnly, let targetPID {
            base = base.filter { $0.pid == targetPID }
        }
        apply(windows: ordered(base), preferredID: nil)

        guard includeMinimized || showTabs || !currentSpaceOnly else { return }

        let preferredID = selectedWindow?.id
        extendedFetchTask = Task { [weak self] in
            var extended = await WindowManager.shared.fetchExtendedWindows(
                base: base,
                screens: screens,
                includeMinimized: includeMinimized,
                showTabs: showTabs,
                currentSpaceOnly: currentSpaceOnly
            )
            if appOnly, let targetPID {
                extended = extended.filter { $0.pid == targetPID }
            }
            guard !Task.isCancelled, let self else { return }
            guard Set(extended.map(\.id)) != Set(base.map(\.id)) else { return }
            self.apply(windows: self.ordered(extended), preferredID: preferredID)
        }
    }

    private func ordered(_ windows: [WindowInfo]) -> [WindowInfo] {
        guard PreferencesManager.shared.useRecentOrdering else { return windows }
        return WindowActivationHistory.shared.ordered(windows)
    }

    private func apply(windows newWindows: [WindowInfo], preferredID: CGWindowID?) {
        windows = newWindows
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
                self?.slots[id]?.image = image
            }
        }
    }

    func cancelPendingWork() {
        extendedFetchTask?.cancel()
        thumbnailTask?.cancel()
        extendedFetchTask = nil
        thumbnailTask = nil
    }

    // MARK: - Selection

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

    func cycle(forward: Bool) {
        if forward { selectNext() } else { selectPrevious() }
    }

    func navigate(direction: NavigationDirection, columns: Int) {
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

    @discardableResult
    func quickSelect(number: Int) -> WindowInfo? {
        guard number >= 1, number <= filteredWindows.count else { return nil }
        selectedIndex = number - 1
        return selectedWindow
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

    // MARK: - Mutations

    private func mutateWindows(_ mutation: () -> Void) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
            mutation()
            clampSelection()
        }
    }

    func removeWindows(pid: pid_t) {
        mutateWindows {
            windows.removeAll { $0.pid == pid }
        }
    }

    func removeWindow(id: CGWindowID) {
        mutateWindows {
            windows.removeAll { $0.id == id }
        }
    }

    private func clampSelection() {
        let remaining = filteredWindows.count
        selectedIndex = remaining == 0 ? 0 : min(selectedIndex, remaining - 1)
    }

    // MARK: - Modes

    func enterSearchMode() { isSearchMode = true }

    func exitSearchMode() {
        isSearchMode = false
        searchQuery = ""
    }

    func openSettings() { isSettingsOpen = true }
    func closeSettings() { isSettingsOpen = false }
    func toggleSettings() { isSettingsOpen.toggle() }
    func toggleHelp() { isHelpOpen.toggle() }
    func closeHelp() { isHelpOpen = false }
    func togglePreview() { isPreviewOpen.toggle() }
    func closePreview() { isPreviewOpen = false }
}

nonisolated enum SwitcherSheet: Sendable {
    case settings
    case help
    case preview
}

extension SwitcherViewModel {
    var activeSheet: SwitcherSheet? {
        if isSettingsOpen { return .settings }
        if isHelpOpen { return .help }
        if isPreviewOpen { return .preview }
        return nil
    }
}
