import AppKit
import CoreGraphics
import Foundation

let colorSpace = CGColorSpaceCreateDeviceRGB()

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> CGColor {
    NSColor(red: r, green: g, blue: b, alpha: a).cgColor
}

func renderMaster(detailed: Bool) -> CGImage {
    let size = 1024
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else {
        fatalError("Failed to create CGContext")
    }

    // 1. Base Squircle do macOS (Corner Radius 224)
    let squircleRect = CGRect(x: 32, y: 32, width: 960, height: 960)
    let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: 224, cornerHeight: 224, transform: nil)

    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    // Gradiente de chassi retrô anos 80 (Cinza chumbo profundo / CRT arcade)
    let bgColors = [color(0.08, 0.09, 0.15), color(0.04, 0.04, 0.08)] as CFArray
    let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(bgGradient, start: CGPoint(x: 512, y: 992), end: CGPoint(x: 512, y: 32), options: [])

    // 2. Tela CRT Interna com curvatura suave
    let crtRect = CGRect(x: 64, y: 64, width: 896, height: 896)
    let crtPath = CGPath(roundedRect: crtRect, cornerWidth: 160, cornerHeight: 160, transform: nil)
    ctx.addPath(crtPath)
    ctx.setFillColor(color(0.06, 0.07, 0.12))
    ctx.fillPath()

    // Brilho radial central da tela CRT (Vaporwave / Tokyo Night Phosphor)
    let crtColors = [color(0.18, 0.22, 0.38, 0.7), color(0.03, 0.04, 0.07, 0.95)] as CFArray
    let crtGradient = CGGradient(colorsSpace: colorSpace, colors: crtColors, locations: [0.0, 1.0])!
    ctx.drawRadialGradient(
        crtGradient,
        startCenter: CGPoint(x: 512, y: 520),
        startRadius: 40,
        endCenter: CGPoint(x: 512, y: 520),
        endRadius: 520,
        options: []
    )

    // Scanlines sutis estilo monitor anos 80
    if detailed {
        ctx.setStrokeColor(color(0.0, 0.0, 0.0, 0.20))
        ctx.setLineWidth(2.5)
        for y in stride(from: 70, to: 954, by: 7) {
            ctx.move(to: CGPoint(x: 70, y: CGFloat(y)))
            ctx.addLine(to: CGPoint(x: 954, y: CGFloat(y)))
            ctx.strokePath()
        }
    }

    // 3. JANELA TRASEIRA (Anos 80 Vintage GUI - Janela Anterior do Alt-Tab)
    let backWinRect = CGRect(x: 160, y: 360, width: 520, height: 420)
    ctx.setFillColor(NSColor.black.withAlphaComponent(0.7).cgColor)
    ctx.fill(CGRect(x: 176, y: 344, width: 520, height: 420))

    ctx.setFillColor(color(0.12, 0.14, 0.22))
    ctx.fill(backWinRect)

    let backTitleRect = CGRect(x: 160, y: 720, width: 520, height: 60)
    ctx.setFillColor(color(0.18, 0.21, 0.32))
    ctx.fill(backTitleRect)

    if detailed {
        ctx.setStrokeColor(color(0.28, 0.33, 0.48, 0.8))
        ctx.setLineWidth(3)
        for py in stride(from: 730, to: 775, by: 8) {
            ctx.move(to: CGPoint(x: 230, y: CGFloat(py)))
            ctx.addLine(to: CGPoint(x: 610, y: CGFloat(py)))
            ctx.strokePath()
        }

        let backCloseBox = CGRect(x: 178, y: 734, width: 32, height: 32)
        ctx.setFillColor(color(0.24, 0.28, 0.40))
        ctx.fill(backCloseBox)
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setLineWidth(3)
        ctx.stroke(backCloseBox)

        ctx.setFillColor(color(0.08, 0.09, 0.15, 0.9))
        ctx.fill(CGRect(x: 190, y: 440, width: 460, height: 250))
        ctx.setStrokeColor(color(0.18, 0.22, 0.34, 0.6))
        ctx.setLineWidth(2)
        for gy in stride(from: 460, to: 670, by: 30) {
            ctx.move(to: CGPoint(x: 210, y: CGFloat(gy)))
            ctx.addLine(to: CGPoint(x: 630, y: CGFloat(gy)))
            ctx.strokePath()
        }
    }

    ctx.setStrokeColor(color(0.32, 0.38, 0.55))
    ctx.setLineWidth(detailed ? 6 : 12)
    ctx.stroke(backWinRect)

    // 4. JANELA DIANTEIRA (Janela Ativa em Foco com Realce Neon Alt-Tab)
    let frontWinRect = CGRect(x: 340, y: 180, width: 540, height: 460)
    ctx.setFillColor(NSColor.black.withAlphaComponent(0.85).cgColor)
    ctx.fill(CGRect(x: 360, y: 160, width: 540, height: 460))

    ctx.setFillColor(color(0.10, 0.12, 0.20))
    ctx.fill(frontWinRect)

    let frontTitleRect = CGRect(x: 340, y: 580, width: 540, height: 60)
    let titleColors = [color(0.20, 0.35, 0.70), color(0.14, 0.22, 0.50)] as CFArray
    let titleGradient = CGGradient(colorsSpace: colorSpace, colors: titleColors, locations: [0.0, 1.0])!
    ctx.saveGState()
    ctx.addRect(frontTitleRect)
    ctx.clip()
    ctx.drawLinearGradient(titleGradient, start: CGPoint(x: 340, y: 640), end: CGPoint(x: 340, y: 580), options: [])
    ctx.restoreGState()

    if detailed {
        ctx.setStrokeColor(color(0.45, 0.65, 1.0, 0.7))
        ctx.setLineWidth(3)
        for py in stride(from: 590, to: 635, by: 8) {
            ctx.move(to: CGPoint(x: 460, y: CGFloat(py)))
            ctx.addLine(to: CGPoint(x: 810, y: CGFloat(py)))
            ctx.strokePath()
        }

        let widgetColors = [
            color(0.98, 0.40, 0.40),
            color(0.98, 0.80, 0.30),
            color(0.35, 0.90, 0.55)
        ]
        for (index, widget) in widgetColors.enumerated() {
            let box = CGRect(x: 360 + (index * 30), y: 596, width: 20, height: 20)
            ctx.setFillColor(widget)
            ctx.fill(box)
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(2.5)
            ctx.stroke(box)
        }

        let zoomBox = CGRect(x: 835, y: 596, width: 22, height: 22)
        ctx.setFillColor(color(0.30, 0.45, 0.85))
        ctx.fill(zoomBox)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.8).cgColor)
        ctx.setLineWidth(2)
        ctx.stroke(zoomBox)
    }

    let frontContentRect = CGRect(x: 366, y: 206, width: 488, height: 350)
    ctx.setFillColor(color(0.07, 0.08, 0.14))
    ctx.fill(frontContentRect)

    if detailed {
        let miniWindows = [
            CGRect(x: 390, y: 360, width: 125, height: 90),
            CGRect(x: 545, y: 360, width: 125, height: 90),
            CGRect(x: 700, y: 360, width: 125, height: 90)
        ]

        for (index, mini) in miniWindows.enumerated() {
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.6).cgColor)
            ctx.fill(CGRect(x: mini.origin.x + 4, y: mini.origin.y - 4, width: mini.width, height: mini.height))

            let isCurrent = index == 1
            ctx.setFillColor(isCurrent ? color(0.18, 0.28, 0.52) : color(0.12, 0.14, 0.22))
            ctx.fill(mini)

            ctx.setStrokeColor(isCurrent ? color(0.48, 0.76, 1.0) : color(0.25, 0.30, 0.45, 0.8))
            ctx.setLineWidth(isCurrent ? 4 : 2)
            ctx.stroke(mini)

            let miniTitle = CGRect(
                x: mini.origin.x,
                y: mini.origin.y + mini.height - 18,
                width: mini.width,
                height: 18
            )
            ctx.setFillColor(isCurrent ? color(0.30, 0.50, 0.90) : color(0.20, 0.23, 0.35))
            ctx.fill(miniTitle)
        }
    }

    // 5. SÍMBOLO ALT-TAB
    let arrowScale: CGFloat = detailed ? 1.0 : 1.22
    let arrowCenter = CGPoint(x: 595, y: 277)

    func scaled(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: arrowCenter.x + (point.x - arrowCenter.x) * arrowScale,
            y: arrowCenter.y + (point.y - arrowCenter.y) * arrowScale
        )
    }

    let tabStopBar = CGRect(x: 730, y: 240, width: 20 * arrowScale, height: 75 * arrowScale)
    ctx.setFillColor(color(0.98, 0.82, 0.36))
    ctx.fill(tabStopBar)
    ctx.setStrokeColor(NSColor.black.cgColor)
    ctx.setLineWidth(3)
    ctx.stroke(tabStopBar)

    let arrowPoints = [
        CGPoint(x: 480, y: 265), CGPoint(x: 640, y: 265), CGPoint(x: 640, y: 240),
        CGPoint(x: 710, y: 277), CGPoint(x: 640, y: 315), CGPoint(x: 640, y: 290),
        CGPoint(x: 480, y: 290)
    ].map(scaled)

    let arrowPath = CGMutablePath()
    arrowPath.move(to: arrowPoints[0])
    for point in arrowPoints.dropFirst() { arrowPath.addLine(to: point) }
    arrowPath.closeSubpath()

    ctx.saveGState()
    ctx.translateBy(x: 5, y: -5)
    ctx.setFillColor(NSColor.black.withAlphaComponent(0.7).cgColor)
    ctx.addPath(arrowPath)
    ctx.fillPath()
    ctx.restoreGState()

    let arrowColors = [color(0.98, 0.82, 0.36), color(0.40, 0.88, 0.98)] as CFArray
    let arrowGradient = CGGradient(colorsSpace: colorSpace, colors: arrowColors, locations: [0.0, 1.0])!
    ctx.saveGState()
    ctx.addPath(arrowPath)
    ctx.clip()
    ctx.drawLinearGradient(arrowGradient, start: CGPoint(x: 480, y: 277), end: CGPoint(x: 710, y: 277), options: [])
    ctx.restoreGState()

    ctx.setStrokeColor(NSColor.black.cgColor)
    ctx.setLineWidth(detailed ? 3.5 : 6)
    ctx.addPath(arrowPath)
    ctx.strokePath()

    if detailed {
        let returnPath = CGMutablePath()
        returnPath.move(to: CGPoint(x: 620, y: 228))
        returnPath.addLine(to: CGPoint(x: 460, y: 228))
        returnPath.addLine(to: CGPoint(x: 460, y: 245))
        returnPath.addLine(to: CGPoint(x: 410, y: 220))
        returnPath.addLine(to: CGPoint(x: 460, y: 195))
        returnPath.addLine(to: CGPoint(x: 460, y: 212))
        returnPath.addLine(to: CGPoint(x: 620, y: 212))
        returnPath.closeSubpath()

        ctx.setFillColor(color(0.35, 0.50, 0.75, 0.9))
        ctx.addPath(returnPath)
        ctx.fillPath()
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setLineWidth(2.5)
        ctx.addPath(returnPath)
        ctx.strokePath()
    }

    // 6. Borda neon da janela dianteira
    ctx.setStrokeColor(color(0.48, 0.72, 1.0))
    ctx.setLineWidth(detailed ? 10 : 18)
    ctx.stroke(frontWinRect)

    if detailed {
        let innerBorder = frontWinRect.insetBy(dx: 6, dy: 6)
        ctx.setStrokeColor(color(0.80, 0.90, 1.0, 0.4))
        ctx.setLineWidth(2)
        ctx.stroke(innerBorder)
    }

    ctx.addPath(squirclePath)
    ctx.setStrokeColor(color(0.45, 0.60, 0.85, 0.4))
    ctx.setLineWidth(4)
    ctx.strokePath()

    ctx.restoreGState()

    guard let image = ctx.makeImage() else {
        fatalError("Failed to render master image")
    }
    return image
}

let detailedMaster = renderMaster(detailed: true)
let simplifiedMaster = renderMaster(detailed: false)

let scriptURL = URL(fileURLWithPath: #filePath)
let projectRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let iconsetURL = projectRoot.appendingPathComponent("Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconsetURL)
try! FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let simplifiedThreshold = 64

let scales: [(name: String, px: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func resample(_ image: CGImage, side: Int) -> CGImage {
    guard let ctx = CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Failed to create resampling context")
    }
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
    guard let resampled = ctx.makeImage() else {
        fatalError("Failed to resample image")
    }
    return resampled
}

func writePNG(_ image: CGImage, side: Int, to url: URL) {
    let resampled = resample(image, side: side)
    let rep = NSBitmapImageRep(cgImage: resampled)
    rep.size = NSSize(width: side, height: side)
    guard let png = rep.representation(using: .png, properties: [:]) else { return }
    try! png.write(to: url)
}

for item in scales {
    let master = item.px <= simplifiedThreshold ? simplifiedMaster : detailedMaster
    writePNG(master, side: item.px, to: iconsetURL.appendingPathComponent(item.name))
}

let imgDirURL = projectRoot.appendingPathComponent("img")
try? FileManager.default.createDirectory(at: imgDirURL, withIntermediateDirectories: true)
writePNG(detailedMaster, side: 512, to: imgDirURL.appendingPathComponent("logo.png"))

print("Iconset (simplified at \(simplifiedThreshold)px and below) and logo.png generated successfully!")
