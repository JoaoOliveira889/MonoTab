# macOS Permissions Guide for MonoTab

MonoTab requires two standard macOS permissions to function as a window switcher. Due to Apple's security architecture, these permissions must be explicitly granted by the user.

---

## 📋 Required Permissions

| Permission | Reason | What MonoTab Does |
| :--- | :--- | :--- |
| **Accessibility** | Global hotkey capture & window switching | Intercepts `⌥ Tab` / `⌘ Tab` and focuses/un-minimizes target windows |
| **Screen Recording** | Real-time window preview thumbnails | Captures crisp thumbnails of active windows via ScreenCaptureKit |

---

## 🛠️ Step-by-Step Setup

### 1. Accessibility (`Privacy & Security > Accessibility`)
1. Open **System Settings** (or click **Enable Accessibility** inside MonoTab).
2. Navigate to **Privacy & Security** → **Accessibility**.
3. Locate **MonoTab** in the list and toggle the switch **ON**.
4. If prompted, enter your macOS password or Touch ID.

> **Why is this required?**
> macOS restricts global event taps (`CGEventTap`) and window focus controls (`AXUIElement`) to authorized accessibility applications. Without this permission, MonoTab cannot intercept hotkeys or bring chosen windows to the front.

---

### 2. Screen Recording (`Privacy & Security > Screen & System Audio Recording`)
1. Open **System Settings** (or click **Enable Screen Recording** inside MonoTab).
2. Navigate to **Privacy & Security** → **Screen & System Audio Recording**.
3. Locate **MonoTab** and toggle the switch **ON**.
4. macOS may prompt you to restart MonoTab. Click **Quit & Reopen** or relaunch via terminal (`monotab`).

> **Why is this required?**
> `ScreenCaptureKit` requires screen recording consent to generate visual previews of open application windows. MonoTab uses window-isolated capture (`SCContentFilter(desktopIndependentWindow:)`), capturing only individual windows rather than full desktop displays.

---

## 🔍 Troubleshooting Permissions

### Permissions not detecting after enabling
1. Open **System Settings** → **Privacy & Security** → **Accessibility**.
2. Select **MonoTab** and click the **`-`** (minus) button to remove it from the list.
3. Re-add MonoTab by clicking **`+`** and selecting `/Applications/MonoTab.app`.
4. Repeat the same removal and re-addition under **Screen & System Audio Recording**.
5. Restart the application:
   ```bash
   killall MonoTab 2>/dev/null
   open /Applications/MonoTab.app
   ```

### Command-Line Permission Reset (TCC)
If permissions get corrupted after recompilation with a new code signature, reset TCC permissions for MonoTab:
```bash
tccutil reset Accessibility com.antigravity.monotab
tccutil reset ScreenCapture com.antigravity.monotab
```
