import Carbon.HIToolbox
import CoreGraphics
import Foundation

enum EventTapError: Error {
    case createFailed
}

final class EventTapManager {
    private var stateMachine: RightCommandStateMachine
    private let sideEffectHandler: ([RightCommandStateMachine.SideEffect]) -> Void
    private let logKeyEvents: Bool

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(
        stateMachine: RightCommandStateMachine,
        logKeyEvents: Bool,
        sideEffectHandler: @escaping ([RightCommandStateMachine.SideEffect]) -> Void
    ) {
        self.stateMachine = stateMachine
        self.logKeyEvents = logKeyEvents
        self.sideEffectHandler = sideEffectHandler
    }

    func start() throws {
        let eventMask = mask(for: .flagsChanged)
            | mask(for: .keyDown)
            | mask(for: .keyUp)

        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, userInfo in
                guard let userInfo else {
                    return Unmanaged.passRetained(event)
                }

                let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()
                return manager.processEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: userInfo
        ) else {
            throw EventTapError.createFailed
        }

        eventTap = tap

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            throw EventTapError.createFailed
        }

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }


    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        runLoopSource = nil
        eventTap = nil
    }

    private func processEvent(
        proxy _: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == EventSynthesizer.syntheticMarker {
            return Unmanaged.passRetained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let rightCommandCode = CGKeyCode(kVK_RightCommand)

        var decision: RightCommandStateMachine.Decision?

        switch type {
        case .flagsChanged:
            if keyCode == rightCommandCode {
                if stateMachine.isRightCommandActive {
                    decision = stateMachine.handleRightCommandUp()
                } else {
                    decision = stateMachine.handleRightCommandDown()
                }
            } else if stateMachine.isRightCommandActive {
                decision = stateMachine.handleOtherKeyActivity()
            }
        case .keyDown, .keyUp:
            if stateMachine.isRightCommandActive {
                decision = stateMachine.handleOtherKeyActivity()
            }
        default:
            break
        }

        guard let decision else {
            return Unmanaged.passRetained(event)
        }

        if logKeyEvents {
            fputs("[rightcmd-agent] type=\(type.rawValue) key=\(keyCode) consume=\(decision.consumeOriginalEvent) effects=\(decision.sideEffects)\n", stderr)
        }

        if !decision.sideEffects.isEmpty {
            sideEffectHandler(decision.sideEffects)
        }

        if decision.consumeOriginalEvent {
            return nil
        }

        return Unmanaged.passRetained(event)
    }

    private func mask(for eventType: CGEventType) -> CGEventMask {
        CGEventMask(1) << eventType.rawValue
    }
}