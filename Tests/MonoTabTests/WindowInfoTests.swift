import XCTest
@testable import MonoTab

final class WindowInfoTests: XCTestCase {
    func testWindowInfoMatching() {
        let window = WindowInfo(
            id: 101,
            pid: 1234,
            appName: "Xcode",
            title: "MonoTab — Package.swift",
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            layer: 0,
            appIcon: nil
        )

        // Matching by app name
        XCTAssertTrue(window.matches(query: "xcode"))
        XCTAssertTrue(window.matches(query: "XCODE"))
        XCTAssertTrue(window.matches(query: "xc"))

        // Matching by window title
        XCTAssertTrue(window.matches(query: "Package"))
        XCTAssertTrue(window.matches(query: "monotab"))

        // Empty query matches everything
        XCTAssertTrue(window.matches(query: ""))
        XCTAssertTrue(window.matches(query: "   "))

        // Unmatched query
        XCTAssertFalse(window.matches(query: "Safari"))
    }

    func testDisplayTitleFallback() {
        let emptyTitleWindow = WindowInfo(
            id: 102,
            pid: 1234,
            appName: "Finder",
            title: "   ",
            bounds: CGRect(x: 0, y: 0, width: 400, height: 300),
            layer: 0,
            appIcon: nil
        )
        XCTAssertEqual(emptyTitleWindow.displayTitle, "Finder")

        let titledWindow = WindowInfo(
            id: 103,
            pid: 1234,
            appName: "Finder",
            title: "Downloads",
            bounds: CGRect(x: 0, y: 0, width: 400, height: 300),
            layer: 0,
            appIcon: nil
        )
        XCTAssertEqual(titledWindow.displayTitle, "Downloads")
    }

    func testWindowInfoEqualityAndHashing() {
        let win1 = WindowInfo(
            id: 42,
            pid: 100,
            appName: "App1",
            title: "Title 1",
            bounds: .zero,
            layer: 0,
            appIcon: nil
        )
        let win2 = WindowInfo(
            id: 42,
            pid: 200,
            appName: "App2",
            title: "Title 2",
            bounds: .zero,
            layer: 0,
            appIcon: nil
        )
        let win3 = WindowInfo(
            id: 43,
            pid: 100,
            appName: "App1",
            title: "Title 1",
            bounds: .zero,
            layer: 0,
            appIcon: nil
        )

        XCTAssertEqual(win1, win2, "Windows with identical id must be equal")
        XCTAssertNotEqual(win1, win3, "Windows with different id must not be equal")
        XCTAssertEqual(win1.hashValue, win2.hashValue)
    }

    func testWindowMinimizedState() {
        let normalWin = WindowInfo(id: 1, pid: 10, appName: "App", title: "Win", bounds: .zero, layer: 0)
        XCTAssertFalse(normalWin.isMinimized)

        let minWin = WindowInfo(id: 2, pid: 10, appName: "App", title: "Win", bounds: .zero, layer: 0, isMinimized: true)
        XCTAssertTrue(minWin.isMinimized)
    }

    @MainActor
    func testPreferencesDefaults() {
        let prefs = PreferencesManager.shared
        // showAppTabs should default to false (windows only, grouped tabs)
        XCTAssertFalse(prefs.showAppTabs)
        // currentSpaceOnly should default to true (current desktop space only)
        XCTAssertTrue(prefs.currentSpaceOnly)
    }

    func testFetchActiveWindowsSafeExecution() {
        let windows = WindowManager.shared.fetchActiveWindows(
            includeMinimized: false,
            showTabs: false,
            currentSpaceOnly: true
        )
        XCTAssertNotNil(windows)
        for win in windows {
            XCTAssertFalse(win.isMinimized, "Active on-screen windows must not be marked as minimized")
        }
    }
}
