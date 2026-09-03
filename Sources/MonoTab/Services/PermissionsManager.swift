import AppKit
import ApplicationServices
import Combine
import Foundation

@MainActor
public final class PermissionsManager: ObservableObject {
    public static let shared = PermissionsManager()

    @Published public private(set) var hasAccessibility: Bool = false
    @Published public private(set) var hasScreenRecording: Bool = false
    @Published public var bannerDismissed: Bool = UserDefaults.standard.bool(forKey: "monotab_banner_dismissed")

    public var allGranted: Bool {
        hasAccessibility && hasScreenRecording
    }

    private init() {
        refresh()
    }

    public func dismissBanner() {
        bannerDismissed = true
        UserDefaults.standard.set(true, forKey: "monotab_banner_dismissed")
    }

    public func refresh() {
        hasAccessibility = checkAccessibility(prompt: false)
        hasScreenRecording = checkScreenRecording(prompt: false)
    }

    @discardableResult
    public func checkAccessibility(prompt: Bool = false) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        self.hasAccessibility = trusted
        return trusted
    }

    @discardableResult
    public func checkScreenRecording(prompt: Bool = false) -> Bool {
        if CGPreflightScreenCaptureAccess() {
            self.hasScreenRecording = true
            return true
        }
        if prompt {
            let requested = CGRequestScreenCaptureAccess()
            self.hasScreenRecording = requested
            return requested
        }
        self.hasScreenRecording = false
        return false
    }

    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
