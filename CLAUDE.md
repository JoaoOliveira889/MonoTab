# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

MonoTab is a macOS window switcher: a hotkey-driven overlay panel listing open windows with thumbnails and search.

## Commands

```bash
make test      # swift test --arch arm64
make build     # swift build -c release --arch arm64
make app       # bundle + codesign with an Apple Development identity
make run       # build bundle, then open it
make run-cli   # run the binary directly, no bundle
make install   # killall, remove old installs, copy to /Applications,
               # symlink ~/.local/bin/{MonoTab,monotab}, relaunch
make clean
```

`install-local` is an alias for `install`. Apple Silicon only, macOS 26.0+, Swift 6.2 tools, `DEVELOPER_DIR` pinned to Xcode. `CODESIGN_IDENTITY` is auto-detected from `security find-identity` and falls back to ad-hoc (`-`) when no Apple Development identity is found.

Makefile output strings are in Portuguese; match that if you add targets.

## Architecture

No external Swift dependencies. Swift 6 language mode with `defaultIsolation(MainActor.self)`, so **every type is main-actor isolated unless it is explicitly marked `nonisolated`** — models, `WindowManager`, `HotkeyManager`, `ScreenSnapshot` and the preference enums all carry that marker. `ExistentialAny`, `InternalImportsByDefault` and `MemberImportVisibility` are on, so nothing in the target is `public`. `Sources/MonoTab/`:

- `MonoTabApp.swift`, `AppDelegate.swift` — entry point and lifecycle. `AppDelegate` only wires things up; hotkeys are delivered straight to `SwitcherPanelController`.
- `Models/` — `WindowInfo.swift` (a plain `Sendable` value holding no lowercased buffers; `WindowSearchKey` carries the UTF-8 match bytes and is built lazily by the view model), `FuzzyMatch.swift`, `AppIconCache.swift`, `SwitcherMetrics.swift` (the single source of truth for card, grid and panel sizing), `HotkeyAction.swift` (the one enum every key maps to) and `WindowActivationHistory.swift` (most-recently-used ordering).
- `Services/` — `WindowManager.swift` (enumeration, activation, window actions, ScreenCaptureKit thumbnails), `ScreenSnapshot.swift` (an immutable, `Sendable` copy of the display geometry plus AppKit ↔ CoreGraphics coordinate conversion), `HotkeyManager.swift`, `PermissionsManager.swift`, `PreferencesManager.swift`, `AppLogger.swift`.
- `UI/` — `SwitcherPanel.swift` (borderless overlay + `SwitcherPanelController`, which is also the `HotkeyManagerDelegate`), `SwitcherView.swift`, `SwitcherViewModel.swift`, `Theme.swift` (accent preference plus the `monoAccent` / `monoReduceMotion` environment keys), `StatusItemController.swift`, and `UI/Components/` (`WindowThumbnailCard`, `SearchBarView`, `PermissionsBannerView`, `SettingsView`, `HelpOverlayView`, `ConfirmationOverlayView`, `ShortcutCatalog`, `KeyCap`, `GlassStyle`).
- `Tests/MonoTabTests/` — Swift Testing (`import Testing`, `@Test`/`#expect`), not XCTest. Keep navigation, metrics, coordinate and window-model logic testable outside the UI.

State uses the `@Observable` macro; there is no Combine and no `ObservableObject` anywhere. Cross-thread state uses `Synchronization.Mutex`, not `NSLock`.

Latency-sensitive invariants worth preserving:

- The event tap source is on the main run loop, so `HotkeyManager` dispatches with `MainActor.assumeIsolated` instead of `DispatchQueue.main.async`. Anything reached from the tap must stay well under the tap's ~1s timeout.
- `WindowManager.fetchOnScreenWindows(screens:)` is synchronous and runs inline while presenting. Everything needing Accessibility IPC lives in `fetchExtendedWindows(...)`, which runs off the main actor and is skipped under the default preferences.
- **No AppKit off the main actor.** Background enumeration receives a `ScreenSnapshot` captured on the main actor; never reach for `NSScreen` from a background path.
- Each window owns an `@Observable` `ThumbnailSlot`, created in `SwitcherViewModel.windows.didSet`, so an arriving capture invalidates one card and no view body ever mutates the slot table. `WindowThumbnailCard` is `Equatable` and used through `.equatable()`, so arrow-key movement re-renders two cards rather than the whole grid.
- Thumbnails are skipped when a cached capture is under 2s old and the window bounds are unchanged, and `SCShareableContent` is cached for 1.5s. Keep both, they are what makes a repeated `⌥ Tab` free.
- The panel is only screen-sized in fullscreen mode. Settings, the shortcut sheet and Quick Look resize the floating panel to `SwitcherMetrics` sizes instead of claiming a screen-sized CoreAnimation backing store. Outside clicks in floating mode come from a global mouse monitor — mouse monitors, unlike keyboard ones, need no Accessibility grant.
- `hide()` bumps `presentationGeneration`; the fade-out completion must keep checking it, otherwise a fast re-show gets ordered out by the previous dismissal.
- Chrome uses the system `glassEffect` through the modifiers in `GlassStyle.swift`, which fall back to opaque fills under *Reduce Transparency*. Cards deliberately do not stack glass. Nothing hardcodes `Color.white` or `Color.black` fills — surfaces are `Color.primary`-relative so light mode holds up; black is only used for drop shadows and dimming layers.
- Animations go through `monoAnimation(_:value:enabled:)` so *Reduce Motion* disables them in one place.
- `WindowManager.resolve` only falls back to geometry matching when `allowGeometryFallback` is true, which is `focus` alone. Destructive or mutating actions (close, minimize, zoom, tile, move) must never act on a guessed window.
- Closing a window and quitting an app route through `SwitcherPanelController.confirm(_:)`, honouring the `confirmDestructiveActions` preference.
- `viewModel.maxGridHeight` is derived from the active display in `layoutPanel()`; do not reintroduce a fixed grid height cap.

`scripts/generate_icon.swift` and `scripts/generate_assets.swift` regenerate `Resources/AppIcon.icns` and related assets. The icon script renders two masters and uses the simplified one at 64px and below; run `iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns` afterwards.

## Conventions

- The app needs Accessibility and Screen Recording permissions; degrade gracefully and surface `PermissionsBannerView` instead of failing silently. `Resources/Entitlements.plist` is applied at codesign time.
- Version lives in `Sources/MonoTab/Models/AppVersion.swift`, `Resources/Info.plist`, and `README.md`. The UI reads `AppInfo.bundleVersion`, which prefers the bundle's `CFBundleShortVersionString`. Always follow [`RULES.md`](./RULES.md) for SemVer increments on each new release.
- `make app` signs with Hardened Runtime (`--options=runtime`). MonoTab is deliberately **not** App Sandboxed — the sandbox is incompatible with Accessibility and cross-app screen capture.
- See `PRIVACY.md` — no data collection.
