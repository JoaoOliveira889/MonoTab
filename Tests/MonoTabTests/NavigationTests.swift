import XCTest
@testable import MonoTab

@MainActor
final class NavigationTests: XCTestCase {
    func testNavigationCycleNextAndPrevious() {
        let vm = SwitcherViewModel()
        let windows = [
            WindowInfo(id: 1, pid: 10, appName: "App A", title: "Win A", bounds: .zero, layer: 0),
            WindowInfo(id: 2, pid: 20, appName: "App B", title: "Win B", bounds: .zero, layer: 0),
            WindowInfo(id: 3, pid: 30, appName: "App C", title: "Win C", bounds: .zero, layer: 0)
        ]
        vm.windows = windows
        vm.selectedIndex = 0

        // Select next
        vm.selectNext()
        XCTAssertEqual(vm.selectedIndex, 1)

        vm.selectNext()
        XCTAssertEqual(vm.selectedIndex, 2)

        // Wrap-around to 0
        vm.selectNext()
        XCTAssertEqual(vm.selectedIndex, 0)

        // Select previous wrap-around to 2
        vm.selectPrevious()
        XCTAssertEqual(vm.selectedIndex, 2)

        vm.selectPrevious()
        XCTAssertEqual(vm.selectedIndex, 1)
    }

    func testGridDirectionalNavigation() {
        let vm = SwitcherViewModel()
        // 6 windows in a 4-column layout
        vm.windows = (1...6).map {
            WindowInfo(id: CGWindowID($0), pid: pid_t($0), appName: "App \($0)", title: "Win \($0)", bounds: .zero, layer: 0)
        }
        vm.selectedIndex = 0

        // Navigate Down with 4 columns: index 0 -> index 4
        vm.navigate(direction: .down, columns: 4)
        XCTAssertEqual(vm.selectedIndex, 4)

        // Navigate Right: index 4 -> index 5
        vm.navigate(direction: .right, columns: 4)
        XCTAssertEqual(vm.selectedIndex, 5)

        // Navigate Down from 5: target 9 >= 6, stays at 5
        vm.navigate(direction: .down, columns: 4)
        XCTAssertEqual(vm.selectedIndex, 5)

        // Navigate Up: index 5 -> index 1
        vm.navigate(direction: .up, columns: 4)
        XCTAssertEqual(vm.selectedIndex, 1)

        // Navigate Left: index 1 -> index 0
        vm.navigate(direction: .left, columns: 4)
        XCTAssertEqual(vm.selectedIndex, 0)
    }

    func testSearchFiltering() {
        let vm = SwitcherViewModel()
        vm.windows = [
            WindowInfo(id: 1, pid: 10, appName: "Terminal", title: "zsh", bounds: .zero, layer: 0),
            WindowInfo(id: 2, pid: 20, appName: "Slack", title: "general", bounds: .zero, layer: 0),
            WindowInfo(id: 3, pid: 30, appName: "Safari", title: "Apple Developer", bounds: .zero, layer: 0)
        ]

        XCTAssertEqual(vm.filteredWindows.count, 3)

        vm.searchQuery = "slack"
        XCTAssertEqual(vm.filteredWindows.count, 1)
        XCTAssertEqual(vm.filteredWindows.first?.appName, "Slack")
        XCTAssertEqual(vm.selectedIndex, 0)

        vm.searchQuery = "apple"
        XCTAssertEqual(vm.filteredWindows.count, 1)
        XCTAssertEqual(vm.filteredWindows.first?.appName, "Safari")

        vm.searchQuery = "nonexistent"
        XCTAssertEqual(vm.filteredWindows.count, 0)
        XCTAssertNil(vm.selectedWindow)
    }
}
