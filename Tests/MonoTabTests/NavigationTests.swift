import CoreGraphics
import Testing
@testable import MonoTab

@Suite("Switcher navigation")
@MainActor
struct NavigationTests {
    private func viewModel(windowCount: Int) -> SwitcherViewModel {
        let viewModel = SwitcherViewModel()
        viewModel.windows = (1...windowCount).map {
            WindowInfo(
                id: CGWindowID($0),
                pid: pid_t($0),
                appName: "App \($0)",
                title: "Win \($0)",
                bounds: .zero
            )
        }
        return viewModel
    }

    @Test("Next and previous wrap around the list")
    func cycling() {
        let viewModel = viewModel(windowCount: 3)
        viewModel.selectedIndex = 0

        viewModel.selectNext()
        #expect(viewModel.selectedIndex == 1)
        viewModel.selectNext()
        #expect(viewModel.selectedIndex == 2)
        viewModel.selectNext()
        #expect(viewModel.selectedIndex == 0)
        viewModel.selectPrevious()
        #expect(viewModel.selectedIndex == 2)
        viewModel.selectPrevious()
        #expect(viewModel.selectedIndex == 1)
    }

    @Test("Grid navigation clamps at the edges")
    func gridNavigation() {
        let viewModel = viewModel(windowCount: 6)
        viewModel.selectedIndex = 0

        viewModel.navigate(direction: .down, columns: 4)
        #expect(viewModel.selectedIndex == 4)

        viewModel.navigate(direction: .right, columns: 4)
        #expect(viewModel.selectedIndex == 5)

        viewModel.navigate(direction: .down, columns: 4)
        #expect(viewModel.selectedIndex == 5)

        viewModel.navigate(direction: .up, columns: 4)
        #expect(viewModel.selectedIndex == 1)

        viewModel.navigate(direction: .left, columns: 4)
        #expect(viewModel.selectedIndex == 0)
    }

    @Test("Search filters the list and resets the selection")
    func searchFiltering() {
        let viewModel = SwitcherViewModel()
        viewModel.windows = [
            WindowInfo(id: 1, pid: 10, appName: "Terminal", title: "zsh", bounds: .zero),
            WindowInfo(id: 2, pid: 20, appName: "Slack", title: "general", bounds: .zero),
            WindowInfo(id: 3, pid: 30, appName: "Safari", title: "Apple Developer", bounds: .zero)
        ]
        #expect(viewModel.filteredWindows.count == 3)

        viewModel.searchQuery = "slack"
        #expect(viewModel.filteredWindows.map(\.appName) == ["Slack"])
        #expect(viewModel.selectedIndex == 0)

        viewModel.searchQuery = "apple"
        #expect(viewModel.filteredWindows.map(\.appName) == ["Safari"])

        viewModel.searchQuery = "nonexistent"
        #expect(viewModel.filteredWindows.isEmpty)
        #expect(viewModel.selectedWindow == nil)
    }

    @Test("Selecting by window id survives reordering")
    func selectByID() {
        let viewModel = viewModel(windowCount: 4)
        viewModel.select(id: 3)
        #expect(viewModel.selectedWindow?.id == 3)

        viewModel.select(id: 999)
        #expect(viewModel.selectedWindow?.id == 3)
    }

    @Test("Removing a window keeps the selection in range")
    func removalAdjustsSelection() {
        let viewModel = viewModel(windowCount: 3)
        viewModel.selectedIndex = 2

        viewModel.removeWindow(id: 3)
        #expect(viewModel.windows.count == 2)
        #expect(viewModel.selectedIndex == 1)

        viewModel.removeWindow(id: 2)
        #expect(viewModel.windows.count == 1)
        #expect(viewModel.selectedIndex == 0)

        viewModel.removeWindow(id: 1)
        #expect(viewModel.windows.isEmpty)
        #expect(viewModel.selectedIndex == 0)
    }

    @Test("Column count stays within the grid bounds", arguments: [0, 1, 2, 4, 8, 14, 40])
    func columnCounts(windowCount: Int) {
        let viewModel = windowCount == 0 ? SwitcherViewModel() : viewModel(windowCount: windowCount)

        for isFullscreen in [true, false] {
            let columns = viewModel.columnCount(isFullscreen: isFullscreen)
            #expect(columns >= 1)
            #expect(columns <= (isFullscreen ? 7 : 5))
        }
    }

    @Test("Each window gets a stable thumbnail slot")
    func thumbnailSlots() {
        let viewModel = viewModel(windowCount: 2)
        #expect(viewModel.slot(for: 1) === viewModel.slot(for: 1))
        #expect(viewModel.slot(for: 1) !== viewModel.slot(for: 2))
    }

    @Test("Quick select selects the exact window by number")
    func quickSelect() {
        let viewModel = viewModel(windowCount: 5)
        let selected1 = viewModel.quickSelect(number: 1)
        #expect(selected1?.id == 1)
        #expect(viewModel.selectedIndex == 0)

        let selected3 = viewModel.quickSelect(number: 3)
        #expect(selected3?.id == 3)
        #expect(viewModel.selectedIndex == 2)

        let invalid = viewModel.quickSelect(number: 99)
        #expect(invalid == nil)
        #expect(viewModel.selectedIndex == 2)
    }

    @Test("Preview state toggles and closes properly")
    func previewState() {
        let viewModel = viewModel(windowCount: 3)
        #expect(!viewModel.isPreviewOpen)

        viewModel.togglePreview()
        #expect(viewModel.isPreviewOpen)

        viewModel.closePreview()
        #expect(!viewModel.isPreviewOpen)

        viewModel.togglePreview()
        #expect(viewModel.isPreviewOpen)
    }

    @Test("Cycling forward and backward matches next and previous")
    func cycleDirections() {
        let viewModel = viewModel(windowCount: 3)
        viewModel.selectedIndex = 0

        viewModel.cycle(forward: true)
        #expect(viewModel.selectedIndex == 1)

        viewModel.cycle(forward: false)
        #expect(viewModel.selectedIndex == 0)

        viewModel.cycle(forward: false)
        #expect(viewModel.selectedIndex == 2)
    }

    @Test("Every window keeps a slot after the list changes")
    func slotsFollowWindows() {
        let viewModel = viewModel(windowCount: 3)
        let firstSlot = viewModel.slot(for: 2)

        viewModel.removeWindow(id: 1)
        #expect(viewModel.slot(for: 2) === firstSlot)
    }

    @Test("The active sheet reflects the open overlay, settings first")
    func activeSheetPriority() {
        let viewModel = viewModel(windowCount: 2)
        #expect(viewModel.activeSheet == nil)

        viewModel.togglePreview()
        #expect(viewModel.activeSheet == .preview)

        viewModel.isHelpOpen = true
        #expect(viewModel.activeSheet == .help)

        viewModel.openSettings()
        #expect(viewModel.activeSheet == .settings)
        #expect(viewModel.isTextEntryActive)
    }
}

@Suite("Window activation history")
@MainActor
struct WindowActivationHistoryTests {
    private func window(id: CGWindowID, pid: pid_t) -> WindowInfo {
        WindowInfo(id: id, pid: pid, appName: "App \(pid)", title: "Win \(id)", bounds: .zero)
    }

    @Test("Most recently focused windows float to the top")
    func recencyOrdering() {
        let history = WindowActivationHistory.shared
        let windows = [window(id: 1, pid: 10), window(id: 2, pid: 20), window(id: 3, pid: 30)]

        for window in windows { history.forget(windowID: window.id) }
        history.record(window: windows[2])
        history.record(window: windows[0])

        let ordered = history.ordered(windows)
        #expect(ordered.map(\.id) == [1, 3, 2])
    }

    @Test("Forgetting a window drops it back to system order")
    func forgetting() {
        let history = WindowActivationHistory.shared
        let windows = [window(id: 7, pid: 70), window(id: 8, pid: 80)]

        history.record(window: windows[1])
        history.forget(windowID: 8)
        history.forget(pid: 80)

        #expect(history.ordered(windows).map(\.id) == [7, 8])
    }
}

@Suite("Screen snapshot")
struct ScreenSnapshotTests {
    private let snapshot = ScreenSnapshot(
        frames: [CGRect(x: 0, y: 0, width: 1440, height: 900)],
        visibleFrames: [CGRect(x: 0, y: 0, width: 1440, height: 875)],
        globalTop: 900
    )

    @Test("Converting between AppKit and CoreGraphics coordinates round-trips")
    func coordinateRoundTrip() {
        let appKit = CGRect(x: 100, y: 50, width: 400, height: 300)
        let coreGraphics = snapshot.coreGraphicsRect(fromAppKit: appKit)

        #expect(coreGraphics.origin.y == 550)
        #expect(snapshot.appKitRect(fromCoreGraphics: coreGraphics) == appKit)
    }

    @Test("A single display reports no display index")
    func singleDisplayIndex() {
        #expect(snapshot.displayIndex(forCoreGraphics: CGRect(x: 0, y: 0, width: 100, height: 100)) == nil)
        #expect(snapshot.screenIndex(containingCoreGraphics: CGRect(x: 10, y: 10, width: 100, height: 100)) == 0)
    }
}

@Suite("Switcher metrics")
struct SwitcherMetricsTests {
    @Test("Row count never drops below one and covers every card")
    func rowCounts() {
        #expect(SwitcherMetrics.rowCount(items: 0, columns: 4) == 1)
        #expect(SwitcherMetrics.rowCount(items: 4, columns: 4) == 1)
        #expect(SwitcherMetrics.rowCount(items: 5, columns: 4) == 2)
        #expect(SwitcherMetrics.rowCount(items: 9, columns: 0) == 9)
    }

    @Test("Fullscreen cards are wider than floating ones")
    func cardSizes() {
        #expect(SwitcherMetrics.card(isFullscreen: true).width > SwitcherMetrics.card(isFullscreen: false).width)
        #expect(SwitcherMetrics.contentWidth(columns: 4, isFullscreen: true)
            > SwitcherMetrics.contentWidth(columns: 4, isFullscreen: false))
    }
}
