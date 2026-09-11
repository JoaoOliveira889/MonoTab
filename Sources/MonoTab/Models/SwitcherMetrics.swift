import CoreGraphics

nonisolated enum SwitcherMetrics {
    static let floatingCard = CGSize(width: 264, height: 162)
    static let fullscreenCard = CGSize(width: 278, height: 172)

    static let columnSpacing: CGFloat = 16
    static let rowSpacing: CGFloat = 14
    static let gridHorizontalPadding: CGFloat = 18
    static let gridVerticalPadding: CGFloat = 8

    static let panelCornerRadius: CGFloat = 24
    static let cardCornerRadius: CGFloat = 14

    static let chromeIdle: CGFloat = 130
    static let chromeSearching: CGFloat = 175
    static let reservedVerticalChrome: CGFloat = 200
    static let screenMargin: CGFloat = 60

    static let minPanelWidth: CGFloat = 700
    static let minPanelHeight: CGFloat = 280
    static let maxFloatingWidth: CGFloat = 1600
    static let maxFullscreenWidth: CGFloat = 2050

    static let settingsSize = CGSize(width: 660, height: 580)
    static let previewSize = CGSize(width: 940, height: 700)
    static let helpSize = CGSize(width: 720, height: 560)

    static func card(isFullscreen: Bool) -> CGSize {
        isFullscreen ? fullscreenCard : floatingCard
    }

    static func contentWidth(columns: Int, isFullscreen: Bool) -> CGFloat {
        let card = card(isFullscreen: isFullscreen)
        let gaps = CGFloat(max(0, columns - 1)) * columnSpacing
        return CGFloat(columns) * card.width + gaps + gridHorizontalPadding * 2 + 48
    }

    static func gridHeight(rows: Int, isFullscreen: Bool) -> CGFloat {
        let card = card(isFullscreen: isFullscreen)
        let gaps = CGFloat(max(0, rows - 1)) * rowSpacing
        return CGFloat(rows) * card.height + gaps + gridVerticalPadding * 3
    }

    static func rowCount(items: Int, columns: Int) -> Int {
        let columns = max(1, columns)
        return max(1, (items + columns - 1) / columns)
    }
}
