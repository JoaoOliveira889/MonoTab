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
}
