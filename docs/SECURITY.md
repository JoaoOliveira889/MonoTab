# Security & Privacy Architecture Report

MonoTab is designed with a strict security model: **Zero Network, Zero Telemetry, Zero Disk Logs, and Local Volatile Memory Only**.

This document summarizes the comprehensive security review conducted on the MonoTab codebase and provides commands to verify these guarantees independently.

---

## 🛡️ Security Audit Findings

### 1. Network & Connectivity (Zero Sockets, Zero HTTP)
- **Framework Imports**: The codebase contains **zero** imports of `Network`, `URLSession`, `WebKit`, `Alamofire`, or socket libraries.
- **Entitlements**: `Resources/Entitlements.plist` explicitly omits both:
  - `com.apple.security.network.client`
  - `com.apple.security.network.server`
- **Hardened Runtime**: The bundle is signed with `--options=runtime`, so code injection, unsigned executable memory and debugger attachment are refused by the kernel. Note that MonoTab is intentionally **not** App Sandboxed — the sandbox is incompatible with the Accessibility and cross-application screen capture the switcher depends on — so the omitted network entitlements document intent rather than being kernel-enforced. The guarantee that no traffic leaves the machine rests on there being no networking code in the binary, which the commands below verify directly.

### 2. Telemetry, Tracking & Analytics (None)
- **External Dependencies**: `Package.swift` has `dependencies: []`.
- **Zero Third-Party SDKs**: No Google Analytics, Firebase, Sentry, Mixpanel, Datadog, or crash reporters.
- **Offline Guarantee**: MonoTab functions identically whether connected to Wi-Fi, Ethernet, or completely air-gapped without internet access.

### 3. Keystroke Protection (Zero Keylogger)
- **Restricted Event Mask**: `CGEventTap` listens only for `keyDown` and `flagsChanged` events.
- **Immediate Pass-Through**: If an incoming keystroke is not an active activation key (`⌥`, `⌘`, `Tab`, arrows, `hjkl`, `Enter`, `Escape`, `f`, `/`), it is returned immediately to the macOS window server untouched via `Unmanaged.passRetained(event)`.
- **Zero Keystroke Storage**: Keystrokes are never recorded, buffered, analyzed, or written anywhere.

### 4. Ephemeral Thumbnails (RAM-Only)
- **ScreenCaptureKit Scoping**: Screen captures are restricted to single target windows via `SCContentFilter(desktopIndependentWindow: scWindow)`. Full screen wallpaper and other windows are not captured.
- **RAM Storage**: Captured `CGImage`s reside strictly in `WindowManager.ThumbnailStore` in memory, behind a `Synchronization.Mutex`, capped at 48 entries.
- **Zero Disk Caching**: Images are never saved to disk (`/tmp`, `~/Library/Caches`, or `UserDefaults`).
- **Memory Purging**: Closed windows are evicted immediately when the window list updates.

### 5. Disk Logging Elimination
- **No File Logging**: All legacy file logs (`/tmp/MonoTab.log`) have been removed.
- **Apple Unified Logging**: The application uses `os.Logger` for a single error channel. Window titles, application names, search queries and keystrokes are never passed to it — the only messages logged are `SMAppService` failures.

---

## 🔬 Reproducible Verification Commands

Verify these security guarantees on your local machine:

### 1. Check for Network Symbols in the Compiled Binary
Verify that no network frameworks or socket symbols exist in the executable:
```bash
nm -u /Applications/MonoTab.app/Contents/MacOS/MonoTab | grep -iE "urlsession|socket|curl|analytics|telemetry|sentry|firebase"
# Expected output: 0 results
```

### 2. Check Sandbox Entitlements
Confirm that the signed binary does not have network client entitlement:
```bash
codesign -d --entitlements :- /Applications/MonoTab.app
```
*Output will show hardened runtime flags with no network entitlements present.*

### 3. Check for Open Network Sockets While Running
Run MonoTab and inspect all open network connections:
```bash
lsof -i -a -p $(pgrep MonoTab)
# Expected output: empty (no network descriptors)
```

### 4. Confirm Hardened Runtime Is Active
```bash
codesign -dv /Applications/MonoTab.app 2>&1 | grep flags
# Expected output: CodeDirectory ... flags=0x10000(runtime)
```

### 5. Verify Absence of Disk Log Files
```bash
ls -la /tmp/MonoTab.log
# Expected output: No such file or directory
```
