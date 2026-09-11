import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Synchronization

@MainActor
protocol HotkeyManagerDelegate: AnyObject {
    func perform(_ action: HotkeyAction)
}

nonisolated final class HotkeyManager: Sendable {
    private enum TriggerModifier: Sendable {
        case option
        case command
    }

    private enum KeyCode {
        static let tab: Int64 = 48
        static let returnKey: Int64 = 36
        static let keypadEnter: Int64 = 76
        static let escape: Int64 = 53
        static let space: Int64 = 49
        static let backtick: Int64 = 50
        static let w: Int64 = 13
        static let q: Int64 = 12
        static let f: Int64 = 3
        static let n: Int64 = 45
        static let slash: Int64 = 44
        static let m: Int64 = 46
        static let z: Int64 = 6
        static let h: Int64 = 4
        static let j: Int64 = 38
        static let k: Int64 = 40
        static let l: Int64 = 37
        static let leftBracket: Int64 = 33
        static let rightBracket: Int64 = 30
        static let arrowLeft: Int64 = 123
        static let arrowRight: Int64 = 124
        static let arrowDown: Int64 = 125
        static let arrowUp: Int64 = 126
    }

    private static let quickSelectKeys: [Int64: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9
    ]

    private static let navigationKeys: [Int64: NavigationDirection] = [
        KeyCode.arrowUp: .up, KeyCode.k: .up,
        KeyCode.arrowDown: .down, KeyCode.j: .down,
        KeyCode.arrowLeft: .left, KeyCode.h: .left,
        KeyCode.arrowRight: .right, KeyCode.l: .right
    ]

    private struct State {
        var isOverlayVisible = false
        var isTextEntryActive = false
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
    @discardableResult
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

    func updateOverlayState(isVisible: Bool, isTextEntryActive: Bool) {
        state.withLock {
            $0.isOverlayVisible = isVisible
            $0.isTextEntryActive = isTextEntryActive
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

    private func send(_ action: HotkeyAction) -> Unmanaged<CGEvent>? {
        onMain { [self] in delegate?.perform(action) }
        return nil
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

        guard snapshot.isOverlayVisible, !snapshot.isTextEntryActive else {
            return Unmanaged.passRetained(event)
        }

        return send(.confirm)
    }

    private func trigger(for flags: CGEventFlags, mode: ShortcutPreference) -> TriggerModifier? {
        if flags.contains(.maskAlternate), mode == .optionTab || mode == .both { return .option }
        if flags.contains(.maskCommand), mode == .commandTab || mode == .both { return .command }
        return nil
    }

    private func handleKeyDown(_ event: CGEvent, _ snapshot: State) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let mode = snapshot.shortcut
        let hasShift = flags.contains(.maskShift)

        if keyCode == KeyCode.tab {
            if let trigger = trigger(for: flags, mode: mode) {
                state.withLock { $0.activeModifier = trigger }
                if snapshot.isOverlayVisible {
                    return send(.cycle(forward: !hasShift))
                }
                return send(.open(appOnly: false))
            }

            if snapshot.isOverlayVisible {
                return send(.cycle(forward: !hasShift))
            }
        }

        if keyCode == KeyCode.backtick, let trigger = trigger(for: flags, mode: mode) {
            state.withLock { $0.activeModifier = trigger }
            if snapshot.isOverlayVisible {
                return send(.cycle(forward: !hasShift))
            }
            return send(.open(appOnly: true))
        }

        guard snapshot.isOverlayVisible else { return Unmanaged.passRetained(event) }

        switch keyCode {
        case KeyCode.returnKey, KeyCode.keypadEnter:
            return send(.confirm)
        case KeyCode.escape:
            return send(.cancel)
        default:
            break
        }

        guard !snapshot.isTextEntryActive else { return Unmanaged.passRetained(event) }

        if let direction = Self.navigationKeys[keyCode] {
            return send(.navigate(direction))
        }

        if let number = Self.quickSelectKeys[keyCode] {
            return send(.quickSelect(number))
        }

        switch keyCode {
        case KeyCode.space:
            return send(.togglePreview)
        case KeyCode.m:
            return send(.toggleMinimize)
        case KeyCode.z:
            return send(.toggleZoom)
        case KeyCode.n:
            return send(.moveToNextDisplay)
        case KeyCode.leftBracket:
            return send(.tile(.left))
        case KeyCode.rightBracket:
            return send(.tile(.right))
        case KeyCode.q where flags.contains(.maskCommand):
            return send(.quitApp)
        case KeyCode.w:
            return send(hasShift ? .hideApp : .closeWindow)
        case KeyCode.slash where hasShift:
            return send(.toggleHelp)
        case KeyCode.f, KeyCode.slash:
            return send(.enterSearch)
        default:
            return Unmanaged.passRetained(event)
        }
    }
}
