import Foundation

struct RightCommandStateMachine {
    enum SideEffect: Equatable {
        case handleRightCommandDownAction
        case handleRightCommandUpAction
    }

    struct Decision: Equatable {
        let consumeOriginalEvent: Bool
        let sideEffects: [SideEffect]
    }

    private enum State: Equatable {
        case idle
        case rightCommandHeld
    }

    private var state: State = .idle

    var isRightCommandActive: Bool {
        state == .rightCommandHeld
    }

    mutating func handleRightCommandDown() -> Decision {
        guard state == .idle else {
            return Decision(consumeOriginalEvent: true, sideEffects: [])
        }

        state = .rightCommandHeld
        return Decision(consumeOriginalEvent: true, sideEffects: [.handleRightCommandDownAction])
    }

    mutating func handleOtherKeyActivity() -> Decision {
        Decision(consumeOriginalEvent: false, sideEffects: [])
    }

    mutating func handleRightCommandUp() -> Decision {
        guard state == .rightCommandHeld else {
            return Decision(consumeOriginalEvent: false, sideEffects: [])
        }

        state = .idle
        return Decision(consumeOriginalEvent: true, sideEffects: [.handleRightCommandUpAction])
    }
}