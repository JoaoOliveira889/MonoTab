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
│  • WindowManager (CGWindowList + ScreenCaptureKit)     │
│  • ThumbnailStore (RAM-only cache behind a Mutex)      │
│  • AppIconCache (main-actor icon memoisation)          │
│  • PermissionsManager (AX & ScreenCapture preflight)   │
│  • PreferencesManager (UserDefaults local storage)     │
└────────────────────────────────────────────────────────┘

Observation is driven by the `@Observable` macro rather than `ObservableObject`/Combine, so a
view only re-renders for the exact properties it reads.
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
- **Thread Safety**: State transitions (`isOverlayVisible`, `isSearchMode`, `isSettingsOpen`, `shortcut`, `activeModifier`) live in a single struct guarded by `Synchronization.Mutex`.
- **Latency**: The tap's run loop source is attached to the main run loop, so the callback already runs on the main thread and dispatches into `@MainActor` work through `MainActor.assumeIsolated` — no `DispatchQueue.main.async` hop per keystroke.

### 2. Hardware-Accelerated Thumbnail Pipeline (`WindowManager`)
- **Discovery**: `CGWindowListCopyWindowInfo` enumerates on-screen windows (and optionally minimized windows) filtered by application type (`activationPolicy == .regular`).
- **Hardware Acceleration**: Uses Apple Silicon media engines via `ScreenCaptureKit`:
  - `SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)` discovers window metadata.
  - `SCScreenshotManager.captureImage(contentFilter:filter, configuration:config)` renders `CGImage`s directly, sized per window to the window's own aspect ratio (bounded by 560x352) with `kCVPixelFormatType_32BGRA`, so ScreenCaptureKit never produces letterbox padding the grid would crop away.
  - Avoids allocating expensive full-display textures (4K/5K).
- **Progressive Streaming**: Captures run through a `TaskGroup` capped at 4 in flight, the selected window first. Each image is delivered to the main actor as it lands.
- **Two-phase enumeration**: `fetchOnScreenWindows()` is a single synchronous `CGWindowListCopyWindowInfo` pass and runs inline while the panel is presented. `fetchExtendedWindows(...)` — minimized windows, background tabs, other spaces — runs off the main actor and merges in afterwards, and is skipped entirely under the default preferences.
- **Accessibility fan-out**: The per-application `kAXWindowsAttribute` queries are blocking IPC capped at 50 ms each, so they are spread across a `DispatchQueue.concurrentPerform` sweep instead of being serialised.

### 3. Ephemeral In-Memory Cache (`ThumbnailStore`)
- **Zero Disk I/O**: Thumbnails are stored strictly in RAM (`[CGWindowID: CGImage]` behind a `Mutex`).
- **Auto-Eviction**: Caps thumbnail storage at 48 entries, dropping the oldest first via an insertion-order list (no per-insert sort).
- **Purge on Close**: Windows no longer present in the window manager list are immediately purged from memory.
- **Instant Response**: Returning to MonoTab displays previously cached thumbnails in 0ms without waiting for ScreenCaptureKit frame capture.
- **Per-card invalidation**: Each window owns an `@Observable` `ThumbnailSlot`, so an arriving image re-renders one card instead of the whole grid.

### 4. Window Focusing, Closing & Restoration
- **Process Activation**: `NSRunningApplication.activate()` brings the target process to the foreground.
- **Accessibility Inspection**: `AXUIElementCreateApplication` and `kAXWindowsAttribute` locate the window by exact `CGWindowID` (one Accessibility call per window), falling back to a title comparison only when the id lookup is unavailable.
- **Non-blocking**: Focus and close run on a detached task with a 0.5 s Accessibility messaging timeout, so an unresponsive target cannot stall the UI.
- **Restoration**: If the window was minimized to the Dock, `kAXMinimizedAttribute` is set to `kCFBooleanFalse`.
- **Elevation**: `kAXRaiseAction` elevates the target window above all other desktop layers.
- **Window Closing**: `kAXCloseButtonAttribute` and `AXUIElementPerformAction(..., kAXPressAction)` simulate clicking the window's close button natively without terminating the application.

### 5. Launch at Login Integration
- **ServiceManagement**: Uses `SMAppService.mainApp` to register and unregister MonoTab directly with macOS System Settings (Login Items).

### 6. Liquid Glass Design System (`GlassStyle`)
- **Native Glass**: macOS 26 renders Liquid Glass itself, so panel chrome, badges and the search field use `glassEffect(_:in:)`. Header controls share one `GlassEffectContainer` so they merge into a single render pass.
- **No Glass On Glass**: Cards sit *on* the glass panel and deliberately opt out — a second glass layer per card would read wrong and cost one blur pass each. They use `Color.primary`-relative fills, which also makes light mode correct.
- **Continuous Bevels**: All panels, cards, and capsules use Apple continuous squircles (`RoundedRectangle(..., style: .continuous)`).
- **Rim Lighting**: Multi-stop specular gradients trace borders to replicate frosted glass optics under varying desktop wallpaper backgrounds.
- **Selection Halo**: Active cards display an interior radial glow and high-contrast accent border with smooth spring physics (`.spring(response: 0.22, dampingFraction: 0.8)`).
