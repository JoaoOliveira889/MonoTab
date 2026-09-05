import AppKit
import ApplicationServices
import Observation

@MainActor
@Observable
final class PermissionsManager {
    static let shared = PermissionsManager()

    private static let cacheLifetime = Duration.milliseconds(750)

    private(set) var hasAccessibility = false
    private(set) var hasScreenRecording = false

    var bannerDismissed: Bool {
        didSet { UserDefaults.standard.set(bannerDismissed, forKey: "monotab_banner_dismissed") }
    }

    @ObservationIgnored private var lastRefresh: ContinuousClock.Instant?

    var allGranted: Bool {
        hasAccessibility && hasScreenRecording
    }

    private init() {
        bannerDismissed = UserDefaults.standard.bool(forKey: "monotab_banner_dismissed")
        refresh(force: true)
    }

    func dismissBanner() {
        bannerDismissed = true
    }

    func refresh(force: Bool = false) {
        let now = ContinuousClock.now
        if !force, let lastRefresh, now - lastRefresh < Self.cacheLifetime { return }
        lastRefresh = now

        hasAccessibility = AXIsProcessTrusted()
        hasScreenRecording = CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    func requestAccessibility() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        hasAccessibility = trusted
        lastRefresh = ContinuousClock.now
        return trusted
    }

    @discardableResult
    func requestScreenRecording() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            hasScreenRecording = true
            return true
        }
        hasScreenRecording = CGRequestScreenCaptureAccess()
        lastRefresh = ContinuousClock.now
        return hasScreenRecording
    }

    func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openScreenRecordingSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    func openAccessibilityPreferences() {
        requestAccessibility()
        openAccessibilitySettings()
    }

    func openScreenRecordingPreferences() {
        requestScreenRecording()
        openScreenRecordingSettings()
    }

    private func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
