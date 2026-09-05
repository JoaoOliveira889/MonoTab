import CoreGraphics
import Testing
@testable import MonoTab

@Suite("WindowInfo")
struct WindowInfoTests {
    private func window(
        id: CGWindowID = 1,
        pid: pid_t = 100,
        appName: String = "App",
        title: String = "Window",
        isMinimized: Bool = false
    ) -> WindowInfo {
        WindowInfo(
            id: id,
            pid: pid,
            appName: appName,
            title: title,
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            isMinimized: isMinimized
        )
    }

    @Test("Matches on app name and title, case insensitively")
    func matching() {
        let xcode = window(appName: "Xcode", title: "MonoTab — Package.swift")

        #expect(xcode.matches(query: "xcode"))
        #expect(xcode.matches(query: "XCODE"))
        #expect(xcode.matches(query: "xc"))
        #expect(xcode.matches(query: "Package"))
        #expect(xcode.matches(query: "monotab"))
        #expect(xcode.matches(query: ""))
        #expect(xcode.matches(query: "   "))
        #expect(!xcode.matches(query: "Safari"))
    }

    @Test("The normalized fast path agrees with the convenience overload")
    func normalizedMatching() {
        let slack = window(appName: "Slack", title: "general")
        #expect(slack.matchScore(normalizedQuery: WindowInfo.normalize("  SLACK ")) != nil)
        #expect(slack.matchScore(normalizedQuery: WindowInfo.normalize("finder")) == nil)
    }

    @Test("Fuzzy initials match the way a switcher is expected to")
    func fuzzyMatching() {
        let code = window(appName: "Visual Studio Code", title: "WindowInfo.swift")
        #expect(code.matches(query: "vsc"))
        #expect(code.matches(query: "vscode"))
        #expect(code.matches(query: "winfo"))
        #expect(!code.matches(query: "zzz"))
    }

    @Test("A contiguous match outranks a scattered one")
    func fuzzyRanking() {
        let query = WindowInfo.normalize("slk")
        let exact = window(appName: "Slk", title: "")
        let scattered = window(appName: "Superlong Kitchen Sink", title: "")

        let exactScore = try! #require(exact.matchScore(normalizedQuery: query))
        let scatteredScore = try! #require(scattered.matchScore(normalizedQuery: query))
        #expect(exactScore > scatteredScore)
    }

    @Test("The app name outranks the window title")
    func appNameWins() {
        let query = WindowInfo.normalize("mail")
        let byApp = window(appName: "Mail", title: "unrelated")
        let byTitle = window(appName: "unrelated", title: "Mail")

        let appScore = try! #require(byApp.matchScore(normalizedQuery: query))
        let titleScore = try! #require(byTitle.matchScore(normalizedQuery: query))
        #expect(appScore > titleScore)
    }

    @Test("Blank titles fall back to the app name")
    func displayTitleFallback() {
        #expect(window(appName: "Finder", title: "   ").displayTitle == "Finder")
        #expect(window(appName: "Finder", title: "").displayTitle == "Finder")
        #expect(window(appName: "Finder", title: "Downloads").displayTitle == "Downloads")
    }

    @Test("Identity is the window id alone")
    func identity() {
        let first = window(id: 42, pid: 100, appName: "App1", title: "Title 1")
        let sameID = window(id: 42, pid: 200, appName: "App2", title: "Title 2")
        let otherID = window(id: 43, pid: 100, appName: "App1", title: "Title 1")

        #expect(first == sameID)
        #expect(first != otherID)
        #expect(first.hashValue == sameID.hashValue)
    }

    @Test("Minimized state round-trips")
    func minimizedFlag() {
        #expect(!window().isMinimized)
        #expect(window(isMinimized: true).isMinimized)
    }
}

@Suite("WindowManager")
struct WindowManagerTests {
    @Test("Enumerating on-screen windows never reports them as minimized")
    func onScreenWindows() {
        for window in WindowManager.shared.fetchOnScreenWindows() {
            #expect(!window.isMinimized)
        }
    }
}

@Suite("PreferencesManager")
@MainActor
struct PreferencesTests {
    @Test("Ships with windows-only, current-space defaults")
    func defaults() {
        let preferences = PreferencesManager.shared
        #expect(!preferences.showAppTabs)
        #expect(preferences.currentSpaceOnly)
    }
}
