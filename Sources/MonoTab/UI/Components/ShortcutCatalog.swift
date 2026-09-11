nonisolated struct ShortcutItem: Identifiable, Sendable {
    let key: String
    let description: String

    var id: String { key }
}

nonisolated struct ShortcutGroup: Identifiable, Sendable {
    let title: String
    let items: [ShortcutItem]

    var id: String { title }
}

nonisolated enum ShortcutCatalog {
    static let groups: [ShortcutGroup] = [
        ShortcutGroup(
            title: "Navigation",
            items: [
                ShortcutItem(key: "⌥ Tab", description: "Open the switcher and cycle forward"),
                ShortcutItem(key: "⌥ ⇧ Tab", description: "Cycle backward"),
                ShortcutItem(key: "⌥ `", description: "Open in app-only mode"),
                ShortcutItem(key: "↑ ↓ ← →", description: "Move across the grid"),
                ShortcutItem(key: "h j k l", description: "Move across the grid, Vim style"),
                ShortcutItem(key: "1 – 9", description: "Jump straight to a card")
            ]
        ),
        ShortcutGroup(
            title: "Window actions",
            items: [
                ShortcutItem(key: "⏎", description: "Switch to the selected window"),
                ShortcutItem(key: "Space", description: "Toggle the large preview"),
                ShortcutItem(key: "w", description: "Close the selected window"),
                ShortcutItem(key: "⇧ w", description: "Hide the owning app"),
                ShortcutItem(key: "m", description: "Minimize or restore"),
                ShortcutItem(key: "z", description: "Zoom (green button)"),
                ShortcutItem(key: "⌘ Q", description: "Quit the owning app")
            ]
        ),
        ShortcutGroup(
            title: "Layout",
            items: [
                ShortcutItem(key: "[", description: "Tile the window to the left half"),
                ShortcutItem(key: "]", description: "Tile the window to the right half"),
                ShortcutItem(key: "n", description: "Move the window to the next display")
            ]
        ),
        ShortcutGroup(
            title: "Switcher",
            items: [
                ShortcutItem(key: "f", description: "Search windows and apps"),
                ShortcutItem(key: "/", description: "Search windows and apps"),
                ShortcutItem(key: "?", description: "Toggle this shortcut sheet"),
                ShortcutItem(key: "⎋", description: "Step back, then dismiss")
            ]
        )
    ]

    static let legend: [ShortcutItem] = [
        ShortcutItem(key: "↑↓←→", description: "Move"),
        ShortcutItem(key: "1-9", description: "Jump"),
        ShortcutItem(key: "Space", description: "Preview"),
        ShortcutItem(key: "w", description: "Close"),
        ShortcutItem(key: "f", description: "Search"),
        ShortcutItem(key: "?", description: "Shortcuts")
    ]
}
