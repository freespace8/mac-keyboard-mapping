import Carbon.HIToolbox
import CoreGraphics
import Foundation

final class EventSynthesizer: @unchecked Sendable {
    static let syntheticMarker: Int64 = 0x52434D44

    private let source: CGEventSource

    init?() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            return nil
        }

        source.localEventsSuppressionInterval = 0
        self.source = source
    }


    func emitLeftCommandOne() {
        postKey(CGKeyCode(kVK_Command), keyDown: true, flags: .maskCommand)
        postKey(CGKeyCode(kVK_ANSI_1), keyDown: true, flags: .maskCommand)
        postKey(CGKeyCode(kVK_ANSI_1), keyDown: false, flags: .maskCommand)
        postKey(CGKeyCode(kVK_Command), keyDown: false, flags: [])
    }

    func emitReturnOrEnter() {
        postKey(CGKeyCode(kVK_Return), keyDown: true, flags: [])
        postKey(CGKeyCode(kVK_Return), keyDown: false, flags: [])
    }

    private func postKey(_ keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags) {
        guard let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCode,
            keyDown: keyDown
        ) else {
            return
        }

        event.flags = flags
        event.setIntegerValueField(.eventSourceUserData, value: EventSynthesizer.syntheticMarker)
        event.post(tap: .cghidEventTap)
    }
}
