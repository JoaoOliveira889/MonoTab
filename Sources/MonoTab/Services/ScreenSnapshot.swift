import AppKit
import CoreGraphics

nonisolated struct ScreenSnapshot: Sendable {
    let frames: [CGRect]
    let visibleFrames: [CGRect]
    let globalTop: CGFloat

    @MainActor
    static func capture() -> ScreenSnapshot {
        let screens = NSScreen.screens
        return ScreenSnapshot(
            frames: screens.map(\.frame),
            visibleFrames: screens.map(\.visibleFrame),
            globalTop: screens.first?.frame.maxY ?? 0
        )
    }

    var count: Int { frames.count }

    func appKitRect(fromCoreGraphics rect: CGRect) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: globalTop - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    func coreGraphicsRect(fromAppKit rect: CGRect) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: globalTop - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    func screenIndex(containingCoreGraphics bounds: CGRect) -> Int? {
        let converted = appKitRect(fromCoreGraphics: bounds)
        let center = CGPoint(x: converted.midX, y: converted.midY)
        if let index = frames.firstIndex(where: { $0.contains(center) }) { return index }
        return frames.isEmpty ? nil : 0
    }

    func displayIndex(forCoreGraphics bounds: CGRect) -> Int? {
        guard frames.count > 1 else { return nil }
        return (screenIndex(containingCoreGraphics: bounds) ?? 0) + 1
    }

    func visibleFrame(at index: Int) -> CGRect? {
        visibleFrames.indices.contains(index) ? visibleFrames[index] : nil
    }
}
