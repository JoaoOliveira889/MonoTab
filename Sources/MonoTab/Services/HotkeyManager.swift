import AppKit
import ApplicationServices
import Synchronization

@MainActor
protocol HotkeyManagerDelegate: AnyObject {
    func hotkeyDidTriggerOpen()
    func hotkeyDidCycleNext()
    func hotkeyDidCyclePrevious()
    func hotkeyDidConfirm()
    func hotkeyDidCancel()
    func hotkeyDidNavigate(direction: HotkeyManager.NavigationDirection)
    func hotkeyDidEnterSearchMode()
    func hotkeyDidCloseSelectedWindow()
    func hotkeyDidQuitSelectedApp()
}

final class HotkeyManager: Sendable {
    enum NavigationDirection: Sendable {
        case left, right, up, down
    }

    private enum TriggerModifier: Sendable {
        case option
        case command
    }

    private enum KeyCode {
        static let tab: Int64 = 48
        static let returnKey: Int64 = 36
        static let keypadEnter: Int64 = 76
        static let escape: Int64 = 53
        static let w: Int64 = 13
        static let q: Int64 = 12
        static let f: Int64 = 3
        static let slash: Int64 = 44
        static let h: Int64 = 4
        static let j: Int64 = 38
        static let k: Int64 = 40
        static let l: Int64 = 37
        static let arrowLeft: Int64 = 123
        static let arrowRight: Int64 = 124
        static let arrowDown: Int64 = 125
        static let arrowUp: Int64 = 126
    }

    private struct State {
        var isOverlayVisible = false
        var isSearchMode = false
        var isSettingsOpen = false
        var shortcut: ShortcutPreference = .both
        var activeModifier: TriggerModifier?
    }

    static let shared = HotkeyManager()

    @MainActor weak var delegate: (any HotkeyManagerDelegate)?
    @MainActor private var eventTap: CFMachPort?
    @MainActor private var runLoopSource: CFRunLoopSource?

    private let state = Mutex(State())

    private init() {}

    @MainActor
    func start() -> Bool {
        stop()

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
                                     (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passRetained(event) }
                return Unmanaged<HotkeyManager>.fromOpaque(refcon)
                    .takeUnretainedValue()
                    .handleEvent(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        return true
    }

    @MainActor
    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    func updateOverlayState(isVisible: Bool, isSearchMode: Bool, isSettingsOpen: Bool) {
        state.withLock {
            $0.isOverlayVisible = isVisible
            $0.isSearchMode = isSearchMode
            $0.isSettingsOpen = isSettingsOpen
            if !isVisible { $0.activeModifier = nil }
        }
    }

    func setShortcutPreference(_ preference: ShortcutPreference) {
        state.withLock { $0.shortcut = preference }
    }

    private func onMain(_ body: @escaping @Sendable @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated(body)
        } else {
            DispatchQueue.main.async { MainActor.assumeIsolated(body) }
        }
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            onMain { [self] in
                if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            }
            return Unmanaged.passRetained(event)
        }

        let snapshot = state.withLock { $0 }

        switch type {
        case .flagsChanged:
            return handleFlagsChanged(event, snapshot)
        case .keyDown:
            return handleKeyDown(event, snapshot)
        default:
            return Unmanaged.passRetained(event)
        }
    }

    private func handleFlagsChanged(_ event: CGEvent, _ snapshot: State) -> Unmanaged<CGEvent>? {
        let flags = event.flags
        let released: Bool
        switch snapshot.activeModifier {
        case .option: released = !flags.contains(.maskAlternate)
        case .command: released = !flags.contains(.maskCommand)
        case nil: released = false
        }
        guard released else { return Unmanaged.passRetained(event) }

        state.withLock { $0.activeModifier = nil }

        guard snapshot.isOverlayVisible, !snapshot.isSearchMode, !snapshot.isSettingsOpen else {
            return Unmanaged.passRetained(event)
        }

        onMain { [self] in delegate?.hotkeyDidConfirm() }
        return nil
    }

    private func handleKeyDown(_ event: CGEvent, _ snapshot: State) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let shiftDown = flags.contains(.maskShift)
        let mode = snapshot.shortcut

        if keyCode == KeyCode.tab {
            let trigger: TriggerModifier?
            if flags.contains(.maskAlternate), mode == .optionTab || mode == .both {
                trigger = .option
            } else if flags.contains(.maskCommand), mode == .commandTab || mode == .both {
                trigger = .command
            } else {
                trigger = nil
            }

            if let trigger {
                state.withLock { $0.activeModifier = trigger }
                let wasVisible = snapshot.isOverlayVisible
                onMain { [self] in
                    if wasVisible {
                        shiftDown ? delegate?.hotkeyDidCyclePrevious() : delegate?.hotkeyDidCycleNext()
                    } else {
                        delegate?.hotkeyDidTriggerOpen()
                    }
                }
                return nil
            }

            if snapshot.isOverlayVisible {
                onMain { [self] in
                    shiftDown ? delegate?.hotkeyDidCyclePrevious() : delegate?.hotkeyDidCycleNext()
                }
                return nil
            }
        }

        guard snapshot.isOverlayVisible else { return Unmanaged.passRetained(event) }

        switch keyCode {
        case KeyCode.returnKey, KeyCode.keypadEnter:
            onMain { [self] in delegate?.hotkeyDidConfirm() }
            return nil
        case KeyCode.escape:
            onMain { [self] in delegate?.hotkeyDidCancel() }
            return nil
        case KeyCode.arrowUp:
            onMain { [self] in delegate?.hotkeyDidNavigate(direction: .up) }
            return nil
        case KeyCode.arrowDown:
            onMain { [self] in delegate?.hotkeyDidNavigate(direction: .down) }
            return nil
        case KeyCode.arrowLeft where !snapshot.isSearchMode:
            onMain { [self] in delegate?.hotkeyDidNavigate(direction: .left) }
            return nil
        case KeyCode.arrowRight where !snapshot.isSearchMode:
            onMain { [self] in delegate?.hotkeyDidNavigate(direction: .right) }
            return nil
        default:
            break
        }

        guard !snapshot.isSearchMode, !snapshot.isSettingsOpen else {
            return Unmanaged.passRetained(event)
        }

        switch keyCode {
        case KeyCode.q where flags.contains(.maskCommand):
            onMain { [self] in delegate?.hotkeyDidQuitSelectedApp() }
            return nil
        case KeyCode.w:
            onMain { [self] in delegate?.hotkeyDidCloseSelectedWindow() }
            return nil
        case KeyCode.f, KeyCode.slash:
            onMain { [self] in delegate?.hotkeyDidEnterSearchMode() }
            return nil
        case KeyCode.h:
            onMain { [self] in delegate?.hotkeyDidNavigate(direction: .left) }
            return nil
        case KeyCode.j:
            onMain { [self] in delegate?.hotkeyDidNavigate(direction: .down) }
            return nil
        case KeyCode.k:
            onMain { [self] in delegate?.hotkeyDidNavigate(direction: .up) }
            return nil
        case KeyCode.l:
            onMain { [self] in delegate?.hotkeyDidNavigate(direction: .right) }
            return nil
        default:
            return Unmanaged.passRetained(event)
        }
    }
}
