import AppKit
import ApplicationServices
import Foundation
import Observation

nonisolated enum PermissionKind: Sendable {
    case accessibility
    case screenRecording

    var settingsURL: String {
        switch self {
        case .accessibility: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .screenRecording: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        }
    }
}

@Observable
final class PermissionsManager {
    static let shared = PermissionsManager()

    private static let cacheLifetime = Duration.milliseconds(750)
    private static let pollInterval = Duration.milliseconds(900)

    private(set) var hasAccessibility = false
    private(set) var hasScreenRecording = false

    var bannerDismissed: Bool {
        didSet { UserDefaults.standard.set(bannerDismissed, forKey: "monotab_banner_dismissed") }
    }

    @ObservationIgnored private var lastRefresh: ContinuousClock.Instant?
    @ObservationIgnored private var pollTask: Task<Void, Never>?

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

    func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pollInterval)
                guard !Task.isCancelled else { return }
                self?.refresh(force: true)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    @discardableResult
    func request(_ kind: PermissionKind) -> Bool {
        lastRefresh = ContinuousClock.now
        switch kind {
        case .accessibility:
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            hasAccessibility = AXIsProcessTrustedWithOptions(options)
            return hasAccessibility
        case .screenRecording:
            hasScreenRecording = CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess()
            return hasScreenRecording
        }
    }

    func openSettings(for kind: PermissionKind) {
        request(kind)
        guard let url = URL(string: kind.settingsURL) else { return }
        NSWorkspace.shared.open(url)
    }
}
