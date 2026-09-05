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

`install-local` is an alias for `install`. Apple Silicon only, macOS 26.0+, Swift 6.0 tools, `DEVELOPER_DIR` pinned to Xcode. `CODESIGN_IDENTITY` is auto-detected from `security find-identity` and falls back to ad-hoc (`-`) when no Apple Development identity is found.

Makefile output strings are in Portuguese; match that if you add targets.

## Architecture

No external Swift dependencies. Swift 6 language mode, `ExistentialAny` and `InternalImportsByDefault` upcoming features are on, so nothing in the target is `public`. `Sources/MonoTab/`:

- `MonoTabApp.swift`, `AppDelegate.swift` — entry point and lifecycle.
- `Models/` — `WindowInfo.swift` (a plain `Sendable` value; it holds no `NSImage`, so it can be built off the main actor), `FuzzyMatch.swift` (subsequence scorer over pre-lowercased UTF-8) and `AppIconCache.swift` (main-actor icon memoisation keyed by pid).
- `Services/` — `WindowManager.swift` (window enumeration, activation, ScreenCaptureKit thumbnails), `HotkeyManager.swift` (global hotkey), `PermissionsManager.swift`, `PreferencesManager.swift`, `AppLogger.swift`.
- `UI/` — `SwitcherPanel.swift` (borderless overlay window + `SwitcherPanelController`), `SwitcherView.swift`, `SwitcherViewModel.swift`, `StatusItemController.swift` (menu bar item), and `UI/Components/` (`WindowThumbnailCard`, `SearchBarView`, `PermissionsBannerView`, `SettingsView`, `GlassStyle`).
- `Tests/MonoTabTests/` — Swift Testing (`import Testing`, `@Test`/`#expect`), not XCTest. Keep navigation and window-model logic testable outside the UI.

State uses the `@Observable` macro; there is no Combine and no `ObservableObject` anywhere. Cross-thread state uses `Synchronization.Mutex`, not `NSLock`.

Latency-sensitive invariants worth preserving:

- The event tap source is on the main run loop, so `HotkeyManager` dispatches with `MainActor.assumeIsolated` instead of `DispatchQueue.main.async`. Anything reached from the tap must stay well under the tap's ~1s timeout.
- `WindowManager.fetchOnScreenWindows()` is synchronous and runs inline while presenting. Everything needing Accessibility IPC lives in `fetchExtendedWindows(...)`, which runs off the main actor and is skipped under the default preferences.
- Each window owns an `@Observable` `ThumbnailSlot` so an arriving capture invalidates one card, not the grid.
- Floating mode sizes the panel window to `hostingView.fittingSize`; only fullscreen mode and the preferences sheet take the whole display. A screen-sized borderless window costs a screen-sized CoreAnimation backing store. Outside clicks in floating mode come from a global mouse monitor — mouse monitors, unlike keyboard ones, need no Accessibility grant.
- Chrome uses the system `glassEffect`. Cards deliberately do not: they sit on the glass panel, and stacking glass would cost a blur pass per card. Nothing hardcodes `Color.white` — fills are `Color.primary`-relative so light mode holds up.
- `viewModel.maxGridHeight` is derived from the active display in `layoutPanel()`; do not reintroduce a fixed grid height cap.

`scripts/generate_icon.swift` and `scripts/generate_assets.swift` regenerate `Resources/AppIcon.icns` and related assets.

## Conventions

- The app needs Accessibility and Screen Recording permissions; degrade gracefully and surface `PermissionsBannerView` instead of failing silently. `Resources/Entitlements.plist` is applied at codesign time.
- Version lives in `Resources/Info.plist` plus the README badges.
- `make app` signs with Hardened Runtime (`--options=runtime`). MonoTab is deliberately **not** App Sandboxed — the sandbox is incompatible with Accessibility and cross-app screen capture.
- See `PRIVACY.md` — no data collection.
