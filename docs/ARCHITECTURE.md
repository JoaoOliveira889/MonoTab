# MonoTab Architecture & Technical Design

MonoTab is engineered exclusively for Apple Silicon (`arm64`) running macOS 26.0+, utilizing the latest hardware media engines and operating system capabilities without legacy backwards-compatibility overhead.

---

## 🏛️ High-Level Architecture

MonoTab combines **AppKit**, **SwiftUI**, **ScreenCaptureKit**, and the macOS **Accessibility API** in a decoupled Model-View-ViewModel (MVVM) pattern:

```
┌────────────────────────────────────────────────────────┐
│                   Global Input Layer                   │
│  CGEventTap (HotkeyManager) ──> HotkeyManagerDelegate  │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│                   Controller Layer                     │
│               SwitcherPanelController                  │
│       Coordinates NSPanel, NSApp activation & VM       │
└─────────────┬───────────────────────────┬──────────────┘
              │                           │
              ▼                           ▼
┌──────────────────────────┐ ┌───────────────────────────┐
│     UI Presentation      │ │       Domain Logic        │
│      (SwitcherView)      │ │   (SwitcherViewModel)     │
│  • Liquid Glass Shaders  │ │  • Active window filter   │
│  • Responsive Grid       │ │  • Search query matcher   │
│  • Spring animations     │ │  • Selection state index  │
└──────────────────────────┘ └─────────────┬─────────────┘
                                           │
                                           ▼
┌────────────────────────────────────────────────────────┐
│                    Service Adapters                    │
│  • WindowManager (CGWindowList + ScreenCaptureKit)    │
│  • FastThumbnailCache (In-memory thread-safe cache)   │
│  • PermissionsManager (AX & ScreenCapture preflight)   │
│  • PreferencesManager (UserDefaults local storage)    │
└────────────────────────────────────────────────────────┘
```

---

## ⚡ Core Subsystems

### 1. Global Hotkey Interception (`HotkeyManager`)
- **Mechanism**: Low-level session event tap created via `CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, ...)`.
- **Event Mask**: Subscribes only to `keyDown` and `flagsChanged`.
- **Zero Keylogger Guarantee**:
  - Keys are inspected strictly to match configured activation shortcuts (`⌥ Tab`, `⌘ Tab`), navigation (`↑ ↓ ← →`, `h j k l`), search trigger (`f`, `/`), confirmation (`Return`), or cancellation (`Escape`).
  - All non-matching keystrokes pass through untouched via `Unmanaged.passRetained(event)`.
  - Keystrokes are never recorded, buffered, or stored.
- **Thread Safety**: State transitions (`isOverlayVisible`, `isSearchMode`, `isSettingsOpen`) are guarded by `NSLock`.

### 2. Hardware-Accelerated Thumbnail Pipeline (`WindowManager`)
- **Discovery**: `CGWindowListCopyWindowInfo` enumerates on-screen windows (and optionally minimized windows) filtered by application type (`activationPolicy == .regular`).
- **Hardware Acceleration**: Uses Apple Silicon media engines via `ScreenCaptureKit`:
  - `SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)` discovers window metadata.
  - `SCScreenshotManager.captureImage(contentFilter:filter, configuration:config)` renders directly at target card dimensions (460x280) with `kCVPixelFormatType_32BGRA`.
  - Avoids allocating expensive full-display textures (4K/5K).
- **Progressive Streaming**: `SwitcherViewModel` loads the previous window's thumbnail first (`prioritizedIndex = 1`), streaming remaining previews asynchronously in a background `Task`.

### 3. Ephemeral In-Memory Cache (`FastThumbnailCache`)
- **Zero Disk I/O**: Thumbnails are stored strictly in RAM (`[CGWindowID: (image: NSImage, date: Date)]`).
- **Auto-Eviction**: Caps thumbnail storage at 60 entries, evicting the oldest 20 entries when capacity is exceeded.
- **Purge on Close**: Windows no longer present in the window manager list are immediately purged from memory.
- **Instant Response**: Returning to MonoTab displays previously cached thumbnails in 0ms without waiting for ScreenCaptureKit frame capture.

### 4. Window Focusing, Closing & Restoration
- **Process Activation**: `NSRunningApplication.activate()` brings the target process to the foreground.
- **Accessibility Inspection**: `AXUIElementCreateApplication` and `kAXWindowsAttribute` locate the matching window by title and coordinates.
- **Restoration**: If the window was minimized to the Dock, `kAXMinimizedAttribute` is set to `kCFBooleanFalse`.
- **Elevation**: `kAXRaiseAction` elevates the target window above all other desktop layers.
- **Window Closing**: `kAXCloseButtonAttribute` and `AXUIElementPerformAction(..., kAXPressAction)` simulate clicking the window's close button natively without terminating the application.

### 5. Launch at Login Integration
- **ServiceManagement**: Uses `SMAppService.mainApp` to register and unregister MonoTab directly with macOS System Settings (Login Items).

### 6. Liquid Glass Design System (`LiquidGlassModifiers`)
- **Optical Layering**: Combines `NSVisualEffectView(.hudWindow)` with ambient gradient depth layers.
- **Continuous Bevels**: All panels, cards, and capsules use Apple continuous squircles (`RoundedRectangle(..., style: .continuous)`).
- **Rim Lighting**: Multi-stop specular gradients trace borders to replicate frosted glass optics under varying desktop wallpaper backgrounds.
- **Selection Halo**: Active cards display an interior radial glow and high-contrast accent border with smooth spring physics (`.spring(response: 0.22, dampingFraction: 0.8)`).
