import AppKit
import CoreGraphics
import Foundation

let scriptURL = URL(fileURLWithPath: #filePath)
let projectRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let imgDir = projectRoot.appendingPathComponent("img")
try? FileManager.default.createDirectory(at: imgDir, withIntermediateDirectories: true)

// ==========================================
// 1. GENERATE img/icon.svg
// ==========================================
let svgIcon = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <defs>
    <!-- Background Chassis Gradient -->
    <linearGradient id="bgGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#141726" />
      <stop offset="100%" stop-color="#0a0a14" />
    </linearGradient>
    
    <!-- CRT Radial Phosphor Glow -->
    <radialGradient id="crtGlow" cx="50%" cy="49%" r="55%">
      <stop offset="0%" stop-color="#2e3861" stop-opacity="0.8" />
      <stop offset="40%" stop-color="#12182b" stop-opacity="0.85" />
      <stop offset="100%" stop-color="#080a12" stop-opacity="0.98" />
    </radialGradient>
    
    <!-- Front Window Title Gradient -->
    <linearGradient id="frontTitleGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#3359b2" />
      <stop offset="100%" stop-color="#243880" />
    </linearGradient>
    
    <!-- Tab Arrow Gradient -->
    <linearGradient id="tabArrowGrad" x1="0%" y1="50%" x2="100%" y2="50%">
      <stop offset="0%" stop-color="#facd5c" />
      <stop offset="100%" stop-color="#66e0fa" />
    </linearGradient>

    <!-- Scanline Pattern -->
    <pattern id="scanlines" width="1024" height="7" patternUnits="userSpaceOnUse">
      <line x1="0" y1="3.5" x2="1024" y2="3.5" stroke="#000000" stroke-width="2" opacity="0.22" />
    </pattern>

    <!-- Squircle Clip Path -->
    <clipPath id="squircleClip">
      <rect x="32" y="32" width="960" height="960" rx="224" ry="224" />
    </clipPath>
  </defs>

  <g clip-path="url(#squircleClip)">
    <!-- Chassis Base -->
    <rect x="32" y="32" width="960" height="960" rx="224" ry="224" fill="url(#bgGrad)" />

    <!-- CRT Screen Base -->
    <rect x="64" y="64" width="896" height="896" rx="160" ry="160" fill="#0f121e" />
    <rect x="64" y="64" width="896" height="896" rx="160" ry="160" fill="url(#crtGlow)" />
    <!-- Scanlines -->
    <rect x="64" y="64" width="896" height="896" rx="160" ry="160" fill="url(#scanlines)" />

    <!-- 1. BACK WINDOW (Retro 1984 Classic GUI) -->
    <!-- Solid 80s Shadow -->
    <rect x="176" y="260" width="520" height="420" fill="#000000" opacity="0.7" />
    <!-- Window Body -->
    <rect x="160" y="244" width="520" height="420" fill="#1f2438" stroke="#52618c" stroke-width="6" />
    <!-- Title Bar -->
    <rect x="160" y="244" width="520" height="60" fill="#2e3652" />
    <!-- Title Bar Pinstripes -->
    <g stroke="#47547a" stroke-width="3">
      <line x1="230" y1="254" x2="610" y2="254" />
      <line x1="230" y1="262" x2="610" y2="262" />
      <line x1="230" y1="270" x2="610" y2="270" />
      <line x1="230" y1="278" x2="610" y2="278" />
      <line x1="230" y1="286" x2="610" y2="286" />
      <line x1="230" y1="294" x2="610" y2="294" />
    </g>
    <!-- Classic Close Box -->
    <rect x="178" y="258" width="32" height="32" fill="#3d4766" stroke="#000000" stroke-width="3" />
    <!-- Inner Schematic Grid -->
    <rect x="190" y="334" width="460" height="250" fill="#141726" opacity="0.9" />
    <g stroke="#2e3857" stroke-width="2" opacity="0.6">
      <line x1="210" y1="364" x2="630" y2="364" />
      <line x1="210" y1="394" x2="630" y2="394" />
      <line x1="210" y1="424" x2="630" y2="424" />
      <line x1="210" y1="454" x2="630" y2="454" />
      <line x1="210" y1="484" x2="630" y2="484" />
      <line x1="210" y1="514" x2="630" y2="514" />
      <line x1="210" y1="544" x2="630" y2="544" />
    </g>

    <!-- 2. FRONT WINDOW (Active Focus Window with Neon Accent) -->
    <!-- Solid Shadow -->
    <rect x="360" y="404" width="540" height="460" fill="#000000" opacity="0.85" />
    <!-- Window Body -->
    <rect x="340" y="384" width="540" height="460" fill="#1a1f33" />
    <!-- Neon Outer Border -->
    <rect x="340" y="384" width="540" height="460" fill="none" stroke="#7ab8ff" stroke-width="10" />
    <!-- Neon Inner Highlight -->
    <rect x="346" y="390" width="528" height="448" fill="none" stroke="#cce6ff" stroke-width="2" opacity="0.4" />
    <!-- Title Bar -->
    <rect x="340" y="384" width="540" height="60" fill="url(#frontTitleGrad)" />
    <!-- Title Bar Pinstripes -->
    <g stroke="#73a6ff" stroke-width="3" opacity="0.7">
      <line x1="460" y1="394" x2="810" y2="394" />
      <line x1="460" y1="402" x2="810" y2="402" />
      <line x1="460" y1="410" x2="810" y2="410" />
      <line x1="460" y1="418" x2="810" y2="418" />
      <line x1="460" y1="426" x2="810" y2="426" />
      <line x1="460" y1="434" x2="810" y2="434" />
    </g>
    <!-- Window Controls -->
    <rect x="360" y="404" width="20" height="20" fill="#fa6666" stroke="#000000" stroke-width="2.5" />
    <rect x="390" y="404" width="20" height="20" fill="#facc4d" stroke="#000000" stroke-width="2.5" />
    <rect x="420" y="404" width="20" height="20" fill="#59e68c" stroke="#000000" stroke-width="2.5" />
    <!-- Zoom Box -->
    <rect x="835" y="402" width="22" height="22" fill="#4d73d9" stroke="#ffffff" stroke-width="2" opacity="0.9" />

    <!-- Content Area -->
    <rect x="366" y="468" width="488" height="350" fill="#121424" />

    <!-- Mini Alt-Tab Preview Windows Inside Content -->
    <!-- Left Mini Window -->
    <rect x="394" y="488" width="125" height="90" fill="#000000" opacity="0.6" />
    <rect x="390" y="484" width="125" height="90" fill="#1f2438" stroke="#404d73" stroke-width="2" />
    <rect x="390" y="484" width="125" height="18" fill="#333b59" />

    <!-- Center Active Mini Window (Highlighted) -->
    <rect x="549" y="488" width="125" height="90" fill="#000000" opacity="0.6" />
    <rect x="545" y="484" width="125" height="90" fill="#2e4785" stroke="#7ac2ff" stroke-width="4" />
    <rect x="545" y="484" width="125" height="18" fill="#4d80e6" />

    <!-- Right Mini Window -->
    <rect x="704" y="488" width="125" height="90" fill="#000000" opacity="0.6" />
    <rect x="700" y="484" width="125" height="90" fill="#1f2438" stroke="#404d73" stroke-width="2" />
    <rect x="700" y="484" width="125" height="18" fill="#333b59" />

    <!-- 3. CENTRAL ALT-TAB PIXEL-ART ARROWS & TAB STOP BAR -->
    <!-- Tab Stop Bar -->
    <rect x="730" y="694" width="20" height="75" fill="#facd5c" stroke="#000000" stroke-width="3" />

    <!-- Main Cycle Arrow (Yellow -> Cyan Gradient) -->
    <!-- Shadow -->
    <path d="M 485 714 L 645 714 L 645 689 L 715 722 L 645 759 L 645 739 L 485 739 Z" fill="#000000" opacity="0.7" />
    <!-- Arrow Body -->
    <path d="M 480 719 L 640 719 L 640 694 L 710 727 L 640 764 L 640 744 L 480 744 Z" fill="url(#tabArrowGrad)" stroke="#000000" stroke-width="3.5" />

    <!-- Return Arrow (Cyan/Blue) -->
    <path d="M 620 781 L 460 781 L 460 764 L 410 789 L 460 814 L 460 797 L 620 797 Z" fill="#5980bf" stroke="#000000" stroke-width="2.5" />
  </g>

  <!-- Outer Squircle Bevel Rim Highlight -->
  <rect x="32" y="32" width="960" height="960" rx="224" ry="224" fill="none" stroke="#7399d9" stroke-width="4" opacity="0.4" />
</svg>
"""

let iconSVGURL = imgDir.appendingPathComponent("icon.svg")
try! svgIcon.write(to: iconSVGURL, atomically: true, encoding: .utf8)
print("==> Created: \(iconSVGURL.path)")

// ==========================================
// 2. GENERATE img/banner.png (1280x420 Retina)
// ==========================================
let bannerWidth = 1280
let bannerHeight = 420
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let bCtx = CGContext(
    data: nil,
    width: bannerWidth,
    height: bannerHeight,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("Banner CGContext failed") }

// Dark backdrop gradient
let bgLocations: [CGFloat] = [0.0, 0.5, 1.0]
let bgColors = [
    NSColor(red: 0.04, green: 0.05, blue: 0.09, alpha: 1.0).cgColor,
    NSColor(red: 0.07, green: 0.09, blue: 0.16, alpha: 1.0).cgColor,
    NSColor(red: 0.03, green: 0.03, blue: 0.06, alpha: 1.0).cgColor
] as CFArray
let bannerBgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations)!
bCtx.drawLinearGradient(bannerBgGrad, start: CGPoint(x: 0, y: 420), end: CGPoint(x: 1280, y: 0), options: [])

// Ambient decorative glow circles
bCtx.saveGState()
let glowColors = [
    NSColor(red: 0.25, green: 0.45, blue: 0.95, alpha: 0.35).cgColor,
    NSColor(red: 0.25, green: 0.45, blue: 0.95, alpha: 0.0).cgColor
] as CFArray
let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0])!
bCtx.drawRadialGradient(glowGrad, startCenter: CGPoint(x: 240, y: 210), startRadius: 20, endCenter: CGPoint(x: 240, y: 210), endRadius: 220, options: [])

let glowCyan = [
    NSColor(red: 0.20, green: 0.85, blue: 0.95, alpha: 0.20).cgColor,
    NSColor(red: 0.20, green: 0.85, blue: 0.95, alpha: 0.0).cgColor
] as CFArray
let glowCyanGrad = CGGradient(colorsSpace: colorSpace, colors: glowCyan, locations: [0.0, 1.0])!
bCtx.drawRadialGradient(glowCyanGrad, startCenter: CGPoint(x: 1050, y: 210), startRadius: 30, endCenter: CGPoint(x: 1050, y: 210), endRadius: 260, options: [])
bCtx.restoreGState()

// Subtle grid lines
bCtx.setStrokeColor(NSColor.white.withAlphaComponent(0.04).cgColor)
bCtx.setLineWidth(1)
for x in stride(from: 40, to: 1240, by: 40) {
    bCtx.move(to: CGPoint(x: x, y: 0))
    bCtx.addLine(to: CGPoint(x: x, y: 420))
    bCtx.strokePath()
}
for y in stride(from: 40, to: 400, by: 40) {
    bCtx.move(to: CGPoint(x: 0, y: y))
    bCtx.addLine(to: CGPoint(x: 1280, y: y))
    bCtx.strokePath()
}

// Draw App Icon on Banner (Left side, centered vertically: (100, 70, 280, 280))
let logoURL = imgDir.appendingPathComponent("logo.png")
if let logoImage = NSImage(contentsOf: logoURL),
   let cgLogo = logoImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
    let iconRect = CGRect(x: 110, y: 70, width: 280, height: 280)
    // Icon drop shadow
    bCtx.saveGState()
    bCtx.setFillColor(NSColor.black.withAlphaComponent(0.5).cgColor)
    bCtx.fill(iconRect.offsetBy(dx: 0, dy: -12).insetBy(dx: -8, dy: -8))
    bCtx.draw(cgLogo, in: iconRect)
    bCtx.restoreGState()
}

// Text content using NSGraphicsContext
let nsGC = NSGraphicsContext(cgContext: bCtx, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsGC

// Brand Title "MonoTab"
let titleFont = NSFont.systemFont(ofSize: 62, weight: .bold)
let titleAttr: [NSAttributedString.Key: Any] = [
    .font: titleFont,
    .foregroundColor: NSColor.white
]
"MonoTab".draw(at: NSPoint(x: 440, y: 265), withAttributes: titleAttr)

// Rocket emoji / accent
let accentFont = NSFont.systemFont(ofSize: 42, weight: .regular)
"🚀".draw(at: NSPoint(x: 725, y: 278), withAttributes: [.font: accentFont])

// Subtitle
let subFont = NSFont.systemFont(ofSize: 22, weight: .medium)
let subAttr: [NSAttributedString.Key: Any] = [
    .font: subFont,
    .foregroundColor: NSColor(red: 0.65, green: 0.75, blue: 0.95, alpha: 1.0)
]
"High-Performance Native Alt+Tab Switcher for macOS".draw(at: NSPoint(x: 440, y: 220), withAttributes: subAttr)

// Badges row
let badgeItems = [
    ("⚡ ScreenCaptureKit", NSColor(red: 0.20, green: 0.75, blue: 1.0, alpha: 1.0)),
    ("💎 Liquid Glass", NSColor(red: 0.70, green: 0.45, blue: 1.0, alpha: 1.0)),
    ("🔒 Zero Telemetry", NSColor(red: 0.35, green: 0.90, blue: 0.55, alpha: 1.0)),
    ("🚀 Swift 6", NSColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 1.0))
]

var curX: CGFloat = 440
let badgeY: CGFloat = 145
for (label, tint) in badgeItems {
    let font = NSFont.systemFont(ofSize: 13, weight: .semibold)
    let textWidth = (label as NSString).size(withAttributes: [.font: font]).width
    let bRect = NSRect(x: curX, y: badgeY, width: textWidth + 24, height: 32)
    
    // Badge pill
    let pillPath = NSBezierPath(roundedRect: bRect, xRadius: 8, yRadius: 8)
    tint.withAlphaComponent(0.12).setFill()
    pillPath.fill()
    tint.withAlphaComponent(0.38).setStroke()
    pillPath.lineWidth = 1.0
    pillPath.stroke()
    
    label.draw(at: NSPoint(x: curX + 12, y: badgeY + 7), withAttributes: [
        .font: font,
        .foregroundColor: tint
    ])
    
    curX += textWidth + 34
}

// Footer micro-copy
let footFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
let footAttr: [NSAttributedString.Key: Any] = [
    .font: footFont,
    .foregroundColor: NSColor.white.withAlphaComponent(0.5)
]
"macOS 26+ • Apple Silicon (ARM64) Only • MIT Open Source".draw(at: NSPoint(x: 440, y: 95), withAttributes: footAttr)

NSGraphicsContext.restoreGraphicsState()

guard let bannerCG = bCtx.makeImage() else { fatalError("Failed to make banner CGImage") }
let bannerNS = NSImage(cgImage: bannerCG, size: NSSize(width: bannerWidth, height: bannerHeight))
if let tiff = bannerNS.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    let bannerURL = imgDir.appendingPathComponent("banner.png")
    try! png.write(to: bannerURL)
    print("==> Created: \(bannerURL.path)")
}

// ==========================================
// 3. GENERATE img/preview.png (Mock UI 1280x800)
// ==========================================
let pWidth = 1280
let pHeight = 800
guard let pCtx = CGContext(
    data: nil,
    width: pWidth,
    height: pHeight,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("Preview CGContext failed") }

// Simulated wallpaper (macOS Dark Moody Gradient)
let wallColors = [
    NSColor(red: 0.08, green: 0.10, blue: 0.18, alpha: 1.0).cgColor,
    NSColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 1.0).cgColor
] as CFArray
let wallGrad = CGGradient(colorsSpace: colorSpace, colors: wallColors, locations: [0.0, 1.0])!
pCtx.drawLinearGradient(wallGrad, start: CGPoint(x: 0, y: 800), end: CGPoint(x: 1280, y: 0), options: [])

// Ambient wallpaper mesh lights
let blueMesh = [
    NSColor(red: 0.15, green: 0.35, blue: 0.85, alpha: 0.25).cgColor,
    NSColor.clear.cgColor
] as CFArray
pCtx.drawRadialGradient(CGGradient(colorsSpace: colorSpace, colors: blueMesh, locations: [0.0, 1.0])!,
                        startCenter: CGPoint(x: 400, y: 550), startRadius: 50,
                        endCenter: CGPoint(x: 400, y: 550), endRadius: 500, options: [])

let purpleMesh = [
    NSColor(red: 0.65, green: 0.20, blue: 0.85, alpha: 0.18).cgColor,
    NSColor.clear.cgColor
] as CFArray
pCtx.drawRadialGradient(CGGradient(colorsSpace: colorSpace, colors: purpleMesh, locations: [0.0, 1.0])!,
                        startCenter: CGPoint(x: 950, y: 350), startRadius: 50,
                        endCenter: CGPoint(x: 950, y: 350), endRadius: 450, options: [])

// macOS Top Menu Bar (Faux)
pCtx.setFillColor(NSColor.black.withAlphaComponent(0.40).cgColor)
pCtx.fill(CGRect(x: 0, y: 770, width: 1280, height: 30))

let pGC = NSGraphicsContext(cgContext: pCtx, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = pGC

let menuFont = NSFont.systemFont(ofSize: 13, weight: .medium)
let menuAttr: [NSAttributedString.Key: Any] = [.font: menuFont, .foregroundColor: NSColor.white.withAlphaComponent(0.85)]
"  Finder  File  Edit  View  Go  Window  Help".draw(at: NSPoint(x: 20, y: 777), withAttributes: menuAttr)
"100% 🔋  Wed Sep 3  14:30".draw(at: NSPoint(x: 1100, y: 777), withAttributes: menuAttr)

// MONOTAB LIQUID GLASS FLOATING HUD
// HUD Panel: Rect (200, 180, 880, 440) -> cornerRadius: 24
let hudRect = NSRect(x: 200, y: 180, width: 880, height: 440)

// Shadow
pCtx.saveGState()
pCtx.setFillColor(NSColor.black.withAlphaComponent(0.55).cgColor)
let shadowPath = CGPath(roundedRect: hudRect.offsetBy(dx: 0, dy: -18), cornerWidth: 26, cornerHeight: 26, transform: nil)
pCtx.addPath(shadowPath)
pCtx.fillPath()
pCtx.restoreGState()

// Liquid Glass HUD Material
let hudPath = NSBezierPath(roundedRect: hudRect, xRadius: 24, yRadius: 24)
NSColor(red: 0.10, green: 0.12, blue: 0.20, alpha: 0.88).setFill()
hudPath.fill()

// Glass Specular Rim Highlight
NSColor.white.withAlphaComponent(0.20).setStroke()
hudPath.lineWidth = 1.0
hudPath.stroke()

// Header: Logo icon + "MonoTab" title + Window Count + Buttons
let headerLogo = NSBezierPath(roundedRect: NSRect(x: 228, y: 574, width: 22, height: 22), xRadius: 5, yRadius: 5)
NSColor(red: 0.25, green: 0.55, blue: 1.0, alpha: 1.0).setFill()
headerLogo.fill()

let hudTitleFont = NSFont.systemFont(ofSize: 15, weight: .bold)
"MonoTab".draw(at: NSPoint(x: 258, y: 577), withAttributes: [.font: hudTitleFont, .foregroundColor: NSColor.white])

// Pill: "4 windows"
let winCountRect = NSRect(x: 820, y: 572, width: 85, height: 26)
let winCountPill = NSBezierPath(roundedRect: winCountRect, xRadius: 13, yRadius: 13)
NSColor.white.withAlphaComponent(0.08).setFill()
winCountPill.fill()
NSColor.white.withAlphaComponent(0.18).setStroke()
winCountPill.lineWidth = 0.75
winCountPill.stroke()
"4 windows".draw(at: NSPoint(x: 832, y: 578), withAttributes: [
    .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
    .foregroundColor: NSColor.white.withAlphaComponent(0.75)
])

// Search Pill Button
let searchBtnRect = NSRect(x: 914, y: 572, width: 88, height: 26)
let searchPill = NSBezierPath(roundedRect: searchBtnRect, xRadius: 13, yRadius: 13)
NSColor.white.withAlphaComponent(0.08).setFill()
searchPill.fill()
NSColor.white.withAlphaComponent(0.18).setStroke()
searchPill.lineWidth = 0.75
searchPill.stroke()
"🔍 Search  f".draw(at: NSPoint(x: 924, y: 578), withAttributes: [
    .font: NSFont.systemFont(ofSize: 11, weight: .medium),
    .foregroundColor: NSColor.white.withAlphaComponent(0.8)
])

// Gear Icon Button
let gearRect = NSRect(x: 1010, y: 572, width: 30, height: 26)
let gearPill = NSBezierPath(roundedRect: gearRect, xRadius: 13, yRadius: 13)
NSColor.white.withAlphaComponent(0.08).setFill()
gearPill.fill()
"⚙️".draw(at: NSPoint(x: 1016, y: 577), withAttributes: [.font: NSFont.systemFont(ofSize: 12)])

// 4 MOCK CARDS (x: 228, 434, 640, 846 -> width: 198, height: 280)
struct MockCard {
    let app: String
    let title: String
    let iconColor: NSColor
    let isSelected: Bool
    let previewHeaderColor: NSColor
}

let mockCards = [
    MockCard(app: "Xcode", title: "MonoTab — Package.swift", iconColor: NSColor(red: 0.15, green: 0.55, blue: 1.0, alpha: 1.0), isSelected: false, previewHeaderColor: NSColor(red: 0.12, green: 0.15, blue: 0.24, alpha: 1.0)),
    MockCard(app: "Terminal", title: "zsh — mono-suite", iconColor: NSColor(red: 0.18, green: 0.20, blue: 0.25, alpha: 1.0), isSelected: true, previewHeaderColor: NSColor(red: 0.10, green: 0.12, blue: 0.18, alpha: 1.0)),
    MockCard(app: "Safari", title: "Apple Developer Docs", iconColor: NSColor(red: 0.10, green: 0.65, blue: 0.95, alpha: 1.0), isSelected: false, previewHeaderColor: NSColor(red: 0.16, green: 0.18, blue: 0.28, alpha: 1.0)),
    MockCard(app: "Notes", title: "Sprint Architecture", iconColor: NSColor(red: 0.98, green: 0.75, blue: 0.25, alpha: 1.0), isSelected: false, previewHeaderColor: NSColor(red: 0.20, green: 0.18, blue: 0.14, alpha: 1.0))
]

let cardY: CGFloat = 250
let cardW: CGFloat = 196
let cardH: CGFloat = 295

for (i, card) in mockCards.enumerated() {
    let cardX = CGFloat(228 + i * 208)
    let cRect = NSRect(x: cardX, y: cardY, width: cardW, height: cardH)
    let cPath = NSBezierPath(roundedRect: cRect, xRadius: 14, yRadius: 14)
    
    if card.isSelected {
        // Selection Halo Glow
        NSColor(red: 0.25, green: 0.50, blue: 1.0, alpha: 0.22).setFill()
        cPath.fill()
        
        NSColor(red: 0.35, green: 0.65, blue: 1.0, alpha: 0.95).setStroke()
        cPath.lineWidth = 2.0
        cPath.stroke()
    } else {
        NSColor.white.withAlphaComponent(0.04).setFill()
        cPath.fill()
        NSColor.white.withAlphaComponent(0.12).setStroke()
        cPath.lineWidth = 1.0
        cPath.stroke()
    }
    
    // Thumbnail screen container
    let thumbRect = NSRect(x: cardX + 10, y: cardY + 70, width: cardW - 20, height: 215)
    let tPath = NSBezierPath(roundedRect: thumbRect, xRadius: 8, yRadius: 8)
    card.previewHeaderColor.setFill()
    tPath.fill()
    
    // Mini mock content inside thumbnail
    if card.app == "Terminal" {
        "$ git status\nOn branch main\nChanges committed.\n$ monotab --version\nMonoTab 1.1.0 (Swift 6)".draw(
            in: thumbRect.insetBy(dx: 12, dy: 12),
            withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 9.5, weight: .regular),
                .foregroundColor: NSColor(red: 0.40, green: 0.90, blue: 0.60, alpha: 0.95)
            ]
        )
    } else if card.app == "Xcode" {
        "import ScreenCaptureKit\nimport SwiftUI\n\n// Hardware accelerated\nlet stream = SCStream(...)".draw(
            in: thumbRect.insetBy(dx: 12, dy: 12),
            withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 9.5, weight: .regular),
                .foregroundColor: NSColor(red: 0.95, green: 0.55, blue: 0.75, alpha: 0.90)
            ]
        )
    } else if card.app == "Safari" {
        "https://developer.apple.com\n\nScreenCaptureKit API\nHigh Performance Capture\nHDR & ProMotion 120fps".draw(
            in: thumbRect.insetBy(dx: 12, dy: 12),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: NSColor(red: 0.70, green: 0.85, blue: 1.0, alpha: 0.90)
            ]
        )
    } else {
        "• Release v1.1.0\n• Liquid Glass optics\n• 0ms perception cache\n• Full ⌘Tab support".draw(
            in: thumbRect.insetBy(dx: 12, dy: 12),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: NSColor(red: 0.95, green: 0.90, blue: 0.75, alpha: 0.90)
            ]
        )
    }
    
    // App icon square
    let iconRect = NSRect(x: cardX + 12, y: cardY + 16, width: 34, height: 34)
    let iPath = NSBezierPath(roundedRect: iconRect, xRadius: 8, yRadius: 8)
    card.iconColor.setFill()
    iPath.fill()
    
    // Window title & app name
    let titleAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12, weight: card.isSelected ? .bold : .semibold),
        .foregroundColor: NSColor.white
    ]
    card.title.draw(in: NSRect(x: cardX + 54, y: cardY + 34, width: cardW - 64, height: 16), withAttributes: titleAttr)
    
    let appAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 10.5, weight: .regular),
        .foregroundColor: NSColor.white.withAlphaComponent(0.6)
    ]
    card.app.draw(at: NSPoint(x: cardX + 54, y: cardY + 18), withAttributes: appAttr)
}

// Bottom Footer: Shortcut hints
let footRect = NSRect(x: 228, y: 195, width: 824, height: 26)
let footHints = [
    ("⌥ / ⌘ ⇥", "Next"),
    ("⇧ ⇥", "Back"),
    ("↑ ↓ ← → / hjkl", "Navigate"),
    ("f or /", "Search"),
    ("⏎", "Select"),
    ("⎋", "Close")
]

var fX: CGFloat = 228
for (key, desc) in footHints {
    let kFont = NSFont.monospacedSystemFont(ofSize: 9.5, weight: .bold)
    let kW = (key as NSString).size(withAttributes: [.font: kFont]).width
    let pill = NSRect(x: fX, y: 198, width: kW + 10, height: 18)
    let pPath = NSBezierPath(roundedRect: pill, xRadius: 4, yRadius: 4)
    NSColor.white.withAlphaComponent(0.12).setFill()
    pPath.fill()
    NSColor.white.withAlphaComponent(0.18).setStroke()
    pPath.lineWidth = 0.5
    pPath.stroke()
    
    key.draw(at: NSPoint(x: fX + 5, y: 201), withAttributes: [.font: kFont, .foregroundColor: NSColor.white])
    
    let dFont = NSFont.systemFont(ofSize: 9.5, weight: .regular)
    desc.draw(at: NSPoint(x: fX + kW + 15, y: 201), withAttributes: [
        .font: dFont,
        .foregroundColor: NSColor.white.withAlphaComponent(0.65)
    ])
    let dW = (desc as NSString).size(withAttributes: [.font: dFont]).width
    fX += kW + dW + 26
}

"Floating Mode".draw(at: NSPoint(x: 975, y: 201), withAttributes: [
    .font: NSFont.systemFont(ofSize: 10, weight: .medium),
    .foregroundColor: NSColor.white.withAlphaComponent(0.6)
])

NSGraphicsContext.restoreGraphicsState()

guard let prevCG = pCtx.makeImage() else { fatalError("Failed to make preview CGImage") }
let prevNS = NSImage(cgImage: prevCG, size: NSSize(width: pWidth, height: pHeight))
if let tiff = prevNS.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    let previewURL = imgDir.appendingPathComponent("preview.png")
    try! png.write(to: previewURL)
    print("==> Created: \(previewURL.path)")
}

print("==> All assets generated successfully!")

// ==========================================
// 4. GENERATE img/preview-search.png (Search Mode Mock UI 1280x800)
// ==========================================
guard let sCtx = CGContext(
    data: nil,
    width: pWidth,
    height: pHeight,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("Search Preview CGContext failed") }

sCtx.drawLinearGradient(wallGrad, start: CGPoint(x: 0, y: 800), end: CGPoint(x: 1280, y: 0), options: [])
sCtx.drawRadialGradient(CGGradient(colorsSpace: colorSpace, colors: blueMesh, locations: [0.0, 1.0])!,
                        startCenter: CGPoint(x: 400, y: 550), startRadius: 50,
                        endCenter: CGPoint(x: 400, y: 550), endRadius: 500, options: [])
sCtx.drawRadialGradient(CGGradient(colorsSpace: colorSpace, colors: purpleMesh, locations: [0.0, 1.0])!,
                        startCenter: CGPoint(x: 950, y: 350), startRadius: 50,
                        endCenter: CGPoint(x: 950, y: 350), endRadius: 450, options: [])

sCtx.setFillColor(NSColor.black.withAlphaComponent(0.40).cgColor)
sCtx.fill(CGRect(x: 0, y: 770, width: 1280, height: 30))

let sGC = NSGraphicsContext(cgContext: sCtx, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = sGC

"  Finder  File  Edit  View  Go  Window  Help".draw(at: NSPoint(x: 20, y: 777), withAttributes: menuAttr)
"100% 🔋  Wed Sep 3  14:30".draw(at: NSPoint(x: 1100, y: 777), withAttributes: menuAttr)

// HUD Panel
sCtx.saveGState()
sCtx.setFillColor(NSColor.black.withAlphaComponent(0.55).cgColor)
sCtx.addPath(shadowPath)
sCtx.fillPath()
sCtx.restoreGState()

NSColor(red: 0.10, green: 0.12, blue: 0.20, alpha: 0.88).setFill()
hudPath.fill()
NSColor.white.withAlphaComponent(0.20).setStroke()
hudPath.lineWidth = 1.0
hudPath.stroke()

headerLogo.fill()
"MonoTab".draw(at: NSPoint(x: 258, y: 577), withAttributes: [.font: hudTitleFont, .foregroundColor: NSColor.white])

// Pill: "1 match"
let matchRect = NSRect(x: 920, y: 572, width: 75, height: 26)
let matchPill = NSBezierPath(roundedRect: matchRect, xRadius: 13, yRadius: 13)
NSColor.white.withAlphaComponent(0.08).setFill()
matchPill.fill()
"1 match".draw(at: NSPoint(x: 932, y: 578), withAttributes: [
    .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
    .foregroundColor: NSColor(red: 0.35, green: 0.85, blue: 1.0, alpha: 1.0)
])
"⚙️".draw(at: NSPoint(x: 1016, y: 577), withAttributes: [.font: NSFont.systemFont(ofSize: 12)])

// Active Search Input Capsule
let searchInputRect = NSRect(x: 228, y: 520, width: 824, height: 38)
let sInputPath = NSBezierPath(roundedRect: searchInputRect, xRadius: 10, yRadius: 10)
NSColor.black.withAlphaComponent(0.35).setFill()
sInputPath.fill()
NSColor(red: 0.35, green: 0.65, blue: 1.0, alpha: 0.85).setStroke()
sInputPath.lineWidth = 1.5
sInputPath.stroke()

"🔍  term|".draw(at: NSPoint(x: 242, y: 530), withAttributes: [
    .font: NSFont.systemFont(ofSize: 14, weight: .regular),
    .foregroundColor: NSColor.white
])

let escPill = NSRect(x: 1010, y: 528, width: 32, height: 20)
let escPath = NSBezierPath(roundedRect: escPill, xRadius: 4, yRadius: 4)
NSColor.white.withAlphaComponent(0.15).setFill()
escPath.fill()
"Esc".draw(at: NSPoint(x: 1017, y: 532), withAttributes: [
    .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .bold),
    .foregroundColor: NSColor.white.withAlphaComponent(0.8)
])

// Filtered Card: Terminal (centered, active)
let singleCardRect = NSRect(x: 520, y: 240, width: 240, height: 260)
let scPath = NSBezierPath(roundedRect: singleCardRect, xRadius: 14, yRadius: 14)
NSColor(red: 0.25, green: 0.50, blue: 1.0, alpha: 0.22).setFill()
scPath.fill()
NSColor(red: 0.35, green: 0.65, blue: 1.0, alpha: 0.95).setStroke()
scPath.lineWidth = 2.0
scPath.stroke()

let sThumbRect = NSRect(x: 532, y: 295, width: 216, height: 185)
let stPath = NSBezierPath(roundedRect: sThumbRect, xRadius: 8, yRadius: 8)
NSColor(red: 0.10, green: 0.12, blue: 0.18, alpha: 1.0).setFill()
stPath.fill()

"$ git status\nOn branch main\nChanges committed.\n$ monotab --version\nMonoTab 1.1.0 (Swift 6)".draw(
    in: sThumbRect.insetBy(dx: 12, dy: 12),
    withAttributes: [
        .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
        .foregroundColor: NSColor(red: 0.40, green: 0.90, blue: 0.60, alpha: 0.95)
    ]
)

let sIconRect = NSRect(x: 532, y: 250, width: 34, height: 34)
let siPath = NSBezierPath(roundedRect: sIconRect, xRadius: 8, yRadius: 8)
NSColor(red: 0.18, green: 0.20, blue: 0.25, alpha: 1.0).setFill()
siPath.fill()

"zsh — mono-suite".draw(in: NSRect(x: 576, y: 268, width: 170, height: 16), withAttributes: [
    .font: NSFont.systemFont(ofSize: 12, weight: .bold),
    .foregroundColor: NSColor.white
])
"Terminal".draw(at: NSPoint(x: 576, y: 252), withAttributes: [
    .font: NSFont.systemFont(ofSize: 10.5, weight: .regular),
    .foregroundColor: NSColor.white.withAlphaComponent(0.6)
])

// Footer
var sfX: CGFloat = 228
for (key, desc) in footHints {
    let kFont = NSFont.monospacedSystemFont(ofSize: 9.5, weight: .bold)
    let kW = (key as NSString).size(withAttributes: [.font: kFont]).width
    let pill = NSRect(x: sfX, y: 198, width: kW + 10, height: 18)
    let pPath = NSBezierPath(roundedRect: pill, xRadius: 4, yRadius: 4)
    NSColor.white.withAlphaComponent(0.12).setFill()
    pPath.fill()
    NSColor.white.withAlphaComponent(0.18).setStroke()
    pPath.lineWidth = 0.5
    pPath.stroke()
    
    key.draw(at: NSPoint(x: sfX + 5, y: 201), withAttributes: [.font: kFont, .foregroundColor: NSColor.white])
    
    let dFont = NSFont.systemFont(ofSize: 9.5, weight: .regular)
    desc.draw(at: NSPoint(x: sfX + kW + 15, y: 201), withAttributes: [
        .font: dFont,
        .foregroundColor: NSColor.white.withAlphaComponent(0.65)
    ])
    let dW = (desc as NSString).size(withAttributes: [.font: dFont]).width
    sfX += kW + dW + 26
}
"Search Active (Mod-Keys Free)".draw(at: NSPoint(x: 885, y: 201), withAttributes: [
    .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
    .foregroundColor: NSColor(red: 0.35, green: 0.85, blue: 1.0, alpha: 0.9)
])

NSGraphicsContext.restoreGraphicsState()

guard let sCG = sCtx.makeImage() else { fatalError("Failed to make search preview CGImage") }
let sNS = NSImage(cgImage: sCG, size: NSSize(width: pWidth, height: pHeight))
if let tiff = sNS.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    let sURL = imgDir.appendingPathComponent("preview-search.png")
    try! png.write(to: sURL)
    print("==> Created: \(sURL.path)")
}
