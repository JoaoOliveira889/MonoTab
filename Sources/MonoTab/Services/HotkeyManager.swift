import AppKit
import ApplicationServices
import Foundation

@MainActor
public protocol HotkeyManagerDelegate: AnyObject {
    func hotkeyDidTriggerOpen()
    func hotkeyDidCycleNext()
    func hotkeyDidCyclePrevious()
    func hotkeyDidReleaseModifier()
    func hotkeyDidConfirm()
    func hotkeyDidCancel()
    func hotkeyDidNavigate(direction: HotkeyManager.NavigationDirection)
    func hotkeyDidEnterSearchMode()
}

public final class HotkeyManager: @unchecked Sendable {
    public enum NavigationDirection: Sendable {
        case left, right, up, down
    }

    private enum ActiveTriggerModifier {
        case option
        case command
    }

    public static let shared = HotkeyManager()

    public weak var delegate: HotkeyManagerDelegate?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fallbackGlobalMonitor: Any?

    private var isOverlayVisibleState: Bool = false
    private var isSearchModeState: Bool = false
    private var isSettingsOpenState: Bool = false
    private var currentShortcutMode: ShortcutPreference = .both
    private var activeModifier: ActiveTriggerModifier? = nil
    private let stateLock = NSLock()

    private init() {}

    public func updateOverlayState(isVisible: Bool, isSearchMode: Bool = false, isSettingsOpen: Bool = false) {
        stateLock.lock()
        self.isOverlayVisibleState = isVisible
        self.isSearchModeState = isSearchMode
        self.isSettingsOpenState = isSettingsOpen
        if !isVisible {
            self.activeModifier = nil
        }
        stateLock.unlock()
    }

    public func setShortcutPreference(_ pref: ShortcutPreference) {
        stateLock.lock()
        self.currentShortcutMode = pref
        stateLock.unlock()
    }

    private var shortcutMode: ShortcutPreference {
        stateLock.lock()
        defer { stateLock.unlock() }
        return currentShortcutMode
    }

    public func start() -> Bool {
        stop()

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
                                     (1 << CGEventType.flagsChanged.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            // Event tap creation failed (usually missing Accessibility permission)
            // Install passive global monitor as fallback so the app isn't completely unresponsive
            installFallbackMonitor()
            return false
        }

        // Tap succeeded: remove any fallback monitor to prevent double-firing
        removeFallbackMonitor()

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        return true
    }

    private func installFallbackMonitor() {
        guard fallbackGlobalMonitor == nil else { return }
        fallbackGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return }
            if event.keyCode == 48 { // Tab key
                let flags = event.modifierFlags
                let isOption = flags.contains(.option)
                let isCommand = flags.contains(.command)
                let currentMode = self.shortcutMode

                var matched = false
                if isOption && (currentMode == .optionTab || currentMode == .both) {
                    matched = true
                } else if isCommand && (currentMode == .commandTab || currentMode == .both) {
                    matched = true
                }

                if matched {
                    DispatchQueue.main.async {
                        if !SwitcherPanelController.shared.isVisible {
                            SwitcherPanelController.shared.show()
                        } else {
                            if flags.contains(.shift) {
                                SwitcherPanelController.shared.viewModel.selectPrevious()
                            } else {
                                SwitcherPanelController.shared.viewModel.selectNext()
                            }
                        }
                    }
                }
            }
        }
    }

    private func removeFallbackMonitor() {
        if let mon = fallbackGlobalMonitor {
            NSEvent.removeMonitor(mon)
            fallbackGlobalMonitor = nil
        }
    }

    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
        }
        removeFallbackMonitor()
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Automatically re-enable tap if system disabled it due to temporary timeout
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        stateLock.lock()
        let visible = isOverlayVisibleState
        let inSearchMode = isSearchModeState
        let inSettings = isSettingsOpenState
        let currentMode = currentShortcutMode
        stateLock.unlock()

        // 1. Modifier release handling (confirms selection when user releases Option / Command)
        if type == .flagsChanged {
            let flags = event.flags
            let optionDown = flags.contains(.maskAlternate)
            let commandDown = flags.contains(.maskCommand)

            stateLock.lock()
            let trigger = self.activeModifier
            stateLock.unlock()

            var modifierReleased = false
            if trigger == .option && !optionDown {
                modifierReleased = true
            } else if trigger == .command && !commandDown {
                modifierReleased = true
            }

            if modifierReleased {
                stateLock.lock()
                self.activeModifier = nil
                stateLock.unlock()

                let keepOpen = inSearchMode || inSettings
                if visible && !keepOpen {
                    DispatchQueue.main.async { [weak self] in
                        self?.delegate?.hotkeyDidReleaseModifier()
                    }
                    return nil
                }
            }
            return Unmanaged.passRetained(event)
        }

        // 2. Key down handling
        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            let optionDown = flags.contains(.maskAlternate)
            let commandDown = flags.contains(.maskCommand)
            let shiftDown = flags.contains(.maskShift)

            // Tab key (KeyCode 48)
            if keyCode == 48 {
                var isShortcutTriggered = false
                var detectedModifier: ActiveTriggerModifier? = nil

                if optionDown && (currentMode == .optionTab || currentMode == .both) {
                    isShortcutTriggered = true
                    detectedModifier = .option
                } else if commandDown && (currentMode == .commandTab || currentMode == .both) {
                    isShortcutTriggered = true
                    detectedModifier = .command
                }

                if isShortcutTriggered {
                    stateLock.lock()
                    self.activeModifier = detectedModifier
                    self.isOverlayVisibleState = true
                    stateLock.unlock()

                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        if !visible {
                            self.delegate?.hotkeyDidTriggerOpen()
                        } else {
                            if shiftDown {
                                self.delegate?.hotkeyDidCyclePrevious()
                            } else {
                                self.delegate?.hotkeyDidCycleNext()
                            }
                        }
                    }
                    return nil
                } else if visible {
                    // While overlay is open, plain Tab / Shift+Tab cycles windows
                    DispatchQueue.main.async { [weak self] in
                        if shiftDown {
                            self?.delegate?.hotkeyDidCyclePrevious()
                        } else {
                            self?.delegate?.hotkeyDidCycleNext()
                        }
                    }
                    return nil
                }
            }

            // Controls when overlay is visible
            if visible {
                // Return / Enter (36, 76)
                if keyCode == 36 || keyCode == 76 {
                    DispatchQueue.main.async { [weak self] in
                        self?.delegate?.hotkeyDidConfirm()
                    }
                    return nil
                }

                // Escape (53)
                if keyCode == 53 {
                    DispatchQueue.main.async { [weak self] in
                        self?.delegate?.hotkeyDidCancel()
                    }
                    return nil
                }

                // Search mode trigger: 'f' (3) or '/' (44) and Vim navigation (h, j, k, l) when not in search or settings mode
                if !inSearchMode && !inSettings {
                    if keyCode == 3 || keyCode == 44 {
                        DispatchQueue.main.async { [weak self] in
                            self?.delegate?.hotkeyDidEnterSearchMode()
                        }
                        return nil
                    }

                    switch keyCode {
                    case 4: // 'h' -> Left
                        DispatchQueue.main.async { [weak self] in
                            self?.delegate?.hotkeyDidNavigate(direction: .left)
                        }
                        return nil
                    case 38: // 'j' -> Down
                        DispatchQueue.main.async { [weak self] in
                            self?.delegate?.hotkeyDidNavigate(direction: .down)
                        }
                        return nil
                    case 40: // 'k' -> Up
                        DispatchQueue.main.async { [weak self] in
                            self?.delegate?.hotkeyDidNavigate(direction: .up)
                        }
                        return nil
                    case 37: // 'l' -> Right
                        DispatchQueue.main.async { [weak self] in
                            self?.delegate?.hotkeyDidNavigate(direction: .right)
                        }
                        return nil
                    default:
                        break
                    }
                }

                // Arrow keys navigation
                switch keyCode {
                case 123: // Left
                    if !inSearchMode {
                        DispatchQueue.main.async { [weak self] in
                            self?.delegate?.hotkeyDidNavigate(direction: .left)
                        }
                        return nil
                    }
                case 124: // Right
                    if !inSearchMode {
                        DispatchQueue.main.async { [weak self] in
                            self?.delegate?.hotkeyDidNavigate(direction: .right)
                        }
                        return nil
                    }
                case 126: // Up
                    DispatchQueue.main.async { [weak self] in
                        self?.delegate?.hotkeyDidNavigate(direction: .up)
                    }
                    return nil
                case 125: // Down
                    DispatchQueue.main.async { [weak self] in
                        self?.delegate?.hotkeyDidNavigate(direction: .down)
                    }
                    return nil
                default:
                    break
                }
            }
        }

        // Pass all other keys directly to the system untouched (Zero Keylogger Guarantee)
        return Unmanaged.passRetained(event)
    }
}
