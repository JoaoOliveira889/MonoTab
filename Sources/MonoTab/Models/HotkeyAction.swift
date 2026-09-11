nonisolated enum NavigationDirection: Sendable {
    case left, right, up, down
}

nonisolated enum TileSide: Sendable {
    case left, right
}

nonisolated enum HotkeyAction: Sendable {
    case open(appOnly: Bool)
    case cycle(forward: Bool)
    case confirm
    case cancel
    case navigate(NavigationDirection)
    case enterSearch
    case toggleHelp
    case togglePreview
    case closeWindow
    case quitApp
    case hideApp
    case toggleMinimize
    case toggleZoom
    case tile(TileSide)
    case moveToNextDisplay
    case quickSelect(Int)
}
