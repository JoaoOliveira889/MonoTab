import AppKit
import CoreGraphics
import Foundation

let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
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
let bgColors = [
    NSColor(red: 0.08, green: 0.09, blue: 0.15, alpha: 1.0).cgColor,
    NSColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 1.0).cgColor
] as CFArray
let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0])!
ctx.drawLinearGradient(bgGradient, start: CGPoint(x: 512, y: 992), end: CGPoint(x: 512, y: 32), options: [])

// 2. Tela CRT Interna com curvatura suave
let crtRect = CGRect(x: 64, y: 64, width: 896, height: 896)
let crtPath = CGPath(roundedRect: crtRect, cornerWidth: 160, cornerHeight: 160, transform: nil)
ctx.addPath(crtPath)
ctx.setFillColor(NSColor(red: 0.06, green: 0.07, blue: 0.12, alpha: 1.0).cgColor)
ctx.fillPath()

// Brilho radial central da tela CRT (Vaporwave / Tokyo Night Phosphor)
let crtColors = [
    NSColor(red: 0.18, green: 0.22, blue: 0.38, alpha: 0.7).cgColor,
    NSColor(red: 0.03, green: 0.04, blue: 0.07, alpha: 0.95).cgColor
] as CFArray
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
ctx.setStrokeColor(NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.20).cgColor)
ctx.setLineWidth(2.5)
for y in stride(from: 70, to: 954, by: 7) {
    ctx.move(to: CGPoint(x: 70, y: CGFloat(y)))
    ctx.addLine(to: CGPoint(x: 954, y: CGFloat(y)))
    ctx.strokePath()
}

// 3. JANELA TRASEIRA (Anos 80 Vintage GUI - Janela Anterior do Alt-Tab)
// Sombra sólida retrô 80s (offset preto sem blur)
let backWinRect = CGRect(x: 160, y: 360, width: 520, height: 420)
ctx.setFillColor(NSColor.black.withAlphaComponent(0.7).cgColor)
ctx.fill(CGRect(x: 176, y: 344, width: 520, height: 420))

// Corpo da Janela Traseira (Cinza escuro retrô)
ctx.setFillColor(NSColor(red: 0.12, green: 0.14, blue: 0.22, alpha: 1.0).cgColor)
ctx.fill(backWinRect)

// Barra de Título Retrô com linhas horizontais estilo Classic 1984 Mac OS
let backTitleRect = CGRect(x: 160, y: 720, width: 520, height: 60)
ctx.setFillColor(NSColor(red: 0.18, green: 0.21, blue: 0.32, alpha: 1.0).cgColor)
ctx.fill(backTitleRect)

// Linhas pinstripes da barra de título retrô
ctx.setStrokeColor(NSColor(red: 0.28, green: 0.33, blue: 0.48, alpha: 0.8).cgColor)
ctx.setLineWidth(3)
for py in stride(from: 730, to: 775, by: 8) {
    ctx.move(to: CGPoint(x: 230, y: CGFloat(py)))
    ctx.addLine(to: CGPoint(x: 610, y: CGFloat(py)))
    ctx.strokePath()
}

// Caixa de fechar retrô clássica 80s (quadrado com borda)
let backCloseBox = CGRect(x: 178, y: 734, width: 32, height: 32)
ctx.setFillColor(NSColor(red: 0.24, green: 0.28, blue: 0.40, alpha: 1.0).cgColor)
ctx.fill(backCloseBox)
ctx.setStrokeColor(NSColor.black.cgColor)
ctx.setLineWidth(3)
ctx.stroke(backCloseBox)

// Miniatura esquemática pixelada na janela de trás
ctx.setFillColor(NSColor(red: 0.08, green: 0.09, blue: 0.15, alpha: 0.9).cgColor)
ctx.fill(CGRect(x: 190, y: 440, width: 460, height: 250))
// Grade de linhas na janela de trás
ctx.setStrokeColor(NSColor(red: 0.18, green: 0.22, blue: 0.34, alpha: 0.6).cgColor)
ctx.setLineWidth(2)
for gy in stride(from: 460, to: 670, by: 30) {
    ctx.move(to: CGPoint(x: 210, y: CGFloat(gy)))
    ctx.addLine(to: CGPoint(x: 630, y: CGFloat(gy)))
    ctx.strokePath()
}

// Borda chanfrada grossa anos 80 da janela traseira
ctx.setStrokeColor(NSColor(red: 0.32, green: 0.38, blue: 0.55, alpha: 1.0).cgColor)
ctx.setLineWidth(6)
ctx.stroke(backWinRect)

// 4. JANELA DIANTEIRA (Janela Ativa em Foco com Realce Neon Alt-Tab)
// Sombra 80s pronunciada
let frontWinRect = CGRect(x: 340, y: 180, width: 540, height: 460)
ctx.setFillColor(NSColor.black.withAlphaComponent(0.85).cgColor)
ctx.fill(CGRect(x: 360, y: 160, width: 540, height: 460))

// Corpo da janela dianteira
ctx.setFillColor(NSColor(red: 0.10, green: 0.12, blue: 0.20, alpha: 1.0).cgColor)
ctx.fill(frontWinRect)

// Barra de título dianteira estilo Windows 1.0/2.0 + Mac 1984
let frontTitleRect = CGRect(x: 340, y: 580, width: 540, height: 60)
let titleColors = [
    NSColor(red: 0.20, green: 0.35, blue: 0.70, alpha: 1.0).cgColor,
    NSColor(red: 0.14, green: 0.22, blue: 0.50, alpha: 1.0).cgColor
] as CFArray
let titleGradient = CGGradient(colorsSpace: colorSpace, colors: titleColors, locations: [0.0, 1.0])!
ctx.saveGState()
ctx.addRect(frontTitleRect)
ctx.clip()
ctx.drawLinearGradient(titleGradient, start: CGPoint(x: 340, y: 640), end: CGPoint(x: 340, y: 580), options: [])
ctx.restoreGState()

// Pinstripes retrô na barra de título dianteira
ctx.setStrokeColor(NSColor(red: 0.45, green: 0.65, blue: 1.0, alpha: 0.7).cgColor)
ctx.setLineWidth(3)
for py in stride(from: 590, to: 635, by: 8) {
    ctx.move(to: CGPoint(x: 460, y: CGFloat(py)))
    ctx.addLine(to: CGPoint(x: 810, y: CGFloat(py)))
    ctx.strokePath()
}

// Botões de controle retrô estilo 80s (quadrados com chanfro pixelado)
let widgetColors = [
    NSColor(red: 0.98, green: 0.40, blue: 0.40, alpha: 1.0),
    NSColor(red: 0.98, green: 0.80, blue: 0.30, alpha: 1.0),
    NSColor(red: 0.35, green: 0.90, blue: 0.55, alpha: 1.0)
]
for (i, c) in widgetColors.enumerated() {
    let box = CGRect(x: 360 + (i * 30), y: 596, width: 20, height: 20)
    ctx.setFillColor(c.cgColor)
    ctx.fill(box)
    ctx.setStrokeColor(NSColor.black.cgColor)
    ctx.setLineWidth(2.5)
    ctx.stroke(box)
}

// Botão de zoom/maximize retrô à direita
let zoomBox = CGRect(x: 835, y: 596, width: 22, height: 22)
ctx.setFillColor(NSColor(red: 0.30, green: 0.45, blue: 0.85, alpha: 1.0).cgColor)
ctx.fill(zoomBox)
ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.8).cgColor)
ctx.setLineWidth(2)
ctx.stroke(zoomBox)

// Área de conteúdo da janela ativa: interior com tema switcher
let frontContentRect = CGRect(x: 366, y: 206, width: 488, height: 350)
ctx.setFillColor(NSColor(red: 0.07, green: 0.08, blue: 0.14, alpha: 1.0).cgColor)
ctx.fill(frontContentRect)

// Mini-janelas internas pixel-art representando a grade do Alt-Tab
let miniWindows = [
    CGRect(x: 390, y: 360, width: 125, height: 90),
    CGRect(x: 545, y: 360, width: 125, height: 90),
    CGRect(x: 700, y: 360, width: 125, height: 90)
]

for (idx, mrect) in miniWindows.enumerated() {
    ctx.setFillColor(NSColor.black.withAlphaComponent(0.6).cgColor)
    ctx.fill(CGRect(x: mrect.origin.x + 4, y: mrect.origin.y - 4, width: mrect.width, height: mrect.height))

    let isCurrent = (idx == 1) // Janela do meio em foco
    ctx.setFillColor(isCurrent ? NSColor(red: 0.18, green: 0.28, blue: 0.52, alpha: 1.0).cgColor : NSColor(red: 0.12, green: 0.14, blue: 0.22, alpha: 1.0).cgColor)
    ctx.fill(mrect)

    ctx.setStrokeColor(isCurrent ? NSColor(red: 0.48, green: 0.76, blue: 1.0, alpha: 1.0).cgColor : NSColor(red: 0.25, green: 0.30, blue: 0.45, alpha: 0.8).cgColor)
    ctx.setLineWidth(isCurrent ? 4 : 2)
    ctx.stroke(mrect)

    let mTitle = CGRect(x: mrect.origin.x, y: mrect.origin.y + mrect.height - 18, width: mrect.width, height: 18)
    ctx.setFillColor(isCurrent ? NSColor(red: 0.30, green: 0.50, blue: 0.90, alpha: 1.0).cgColor : NSColor(red: 0.20, green: 0.23, blue: 0.35, alpha: 1.0).cgColor)
    ctx.fill(mTitle)
}

// 5. ÍCONE CENTRAL PIXEL-ART: SÍMBOLO ALT-TAB (⇥ / Setas de Ciclo Retrô Anos 80)
let tabStopBar = CGRect(x: 730, y: 240, width: 20, height: 75)
ctx.setFillColor(NSColor(red: 0.98, green: 0.82, blue: 0.36, alpha: 1.0).cgColor)
ctx.fill(tabStopBar)
ctx.setStrokeColor(NSColor.black.cgColor)
ctx.setLineWidth(3)
ctx.stroke(tabStopBar)

let arrowPath = CGMutablePath()
arrowPath.move(to: CGPoint(x: 480, y: 265))
arrowPath.addLine(to: CGPoint(x: 640, y: 265))
arrowPath.addLine(to: CGPoint(x: 640, y: 240))
arrowPath.addLine(to: CGPoint(x: 710, y: 277))
arrowPath.addLine(to: CGPoint(x: 640, y: 315))
arrowPath.addLine(to: CGPoint(x: 640, y: 290))
arrowPath.addLine(to: CGPoint(x: 480, y: 290))
arrowPath.closeSubpath()

ctx.saveGState()
ctx.translateBy(x: 5, y: -5)
ctx.setFillColor(NSColor.black.withAlphaComponent(0.7).cgColor)
ctx.addPath(arrowPath)
ctx.fillPath()
ctx.restoreGState()

let arrowColors = [
    NSColor(red: 0.98, green: 0.82, blue: 0.36, alpha: 1.0).cgColor,
    NSColor(red: 0.40, green: 0.88, blue: 0.98, alpha: 1.0).cgColor
] as CFArray
let arrowGradient = CGGradient(colorsSpace: colorSpace, colors: arrowColors, locations: [0.0, 1.0])!
ctx.saveGState()
ctx.addPath(arrowPath)
ctx.clip()
ctx.drawLinearGradient(arrowGradient, start: CGPoint(x: 480, y: 277), end: CGPoint(x: 710, y: 277), options: [])
ctx.restoreGState()

ctx.setStrokeColor(NSColor.black.cgColor)
ctx.setLineWidth(3.5)
ctx.addPath(arrowPath)
ctx.strokePath()

let returnPath = CGMutablePath()
returnPath.move(to: CGPoint(x: 620, y: 228))
returnPath.addLine(to: CGPoint(x: 460, y: 228))
returnPath.addLine(to: CGPoint(x: 460, y: 245))
returnPath.addLine(to: CGPoint(x: 410, y: 220))
returnPath.addLine(to: CGPoint(x: 460, y: 195))
returnPath.addLine(to: CGPoint(x: 460, y: 212))
returnPath.addLine(to: CGPoint(x: 620, y: 212))
returnPath.closeSubpath()

ctx.setFillColor(NSColor(red: 0.35, green: 0.50, blue: 0.75, alpha: 0.9).cgColor)
ctx.addPath(returnPath)
ctx.fillPath()
ctx.setStrokeColor(NSColor.black.cgColor)
ctx.setLineWidth(2.5)
ctx.addPath(returnPath)
ctx.strokePath()

// Borda neon retrô da janela dianteira (#7aa2f7 com realce duplo)
ctx.setStrokeColor(NSColor(red: 0.48, green: 0.72, blue: 1.0, alpha: 1.0).cgColor)
ctx.setLineWidth(10)
ctx.stroke(frontWinRect)

let innerBorder = frontWinRect.insetBy(dx: 6, dy: 6)
ctx.setStrokeColor(NSColor(red: 0.80, green: 0.90, blue: 1.0, alpha: 0.4).cgColor)
ctx.setLineWidth(2)
ctx.stroke(innerBorder)

// 6. Borda externa do Squircle com chanfro luminoso
ctx.addPath(squirclePath)
ctx.setStrokeColor(NSColor(red: 0.45, green: 0.60, blue: 0.85, alpha: 0.4).cgColor)
ctx.setLineWidth(4)
ctx.strokePath()

ctx.restoreGState()

guard let finalImage = ctx.makeImage() else {
    fatalError("Failed to render master image")
}

// 7. Exporta para Iconset
let scriptURL = URL(fileURLWithPath: #filePath)
let projectRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let iconsetURL = projectRoot.appendingPathComponent("Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconsetURL)
try! FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

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

for item in scales {
    let destURL = iconsetURL.appendingPathComponent(item.name)
    let nsImage = NSImage(cgImage: finalImage, size: NSSize(width: item.px, height: item.px))
    guard let tiff = nsImage.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    try! png.write(to: destURL)
}

let imgDirURL = projectRoot.appendingPathComponent("img")
try? FileManager.default.createDirectory(at: imgDirURL, withIntermediateDirectories: true)
let logoDest = imgDirURL.appendingPathComponent("logo.png")
let masterNS = NSImage(cgImage: finalImage, size: NSSize(width: 512, height: 512))
if let tiff = masterNS.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    try? png.write(to: logoDest)
}

print("Iconset and logo.png generated successfully!")

