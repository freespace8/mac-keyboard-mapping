import XCTest
@testable import RightCmdAgent

final class RightCommandStateMachineTests: XCTestCase {
    func testRightCommandDownTriggersPrimaryAction() {
        var stateMachine = RightCommandStateMachine()

        XCTAssertEqual(
            stateMachine.handleRightCommandDown(),
            .init(consumeOriginalEvent: true, sideEffects: [.handleRightCommandDownAction])
        )
    }

    func testRightCommandUpTriggersReleaseActionAfterPress() {
        var stateMachine = RightCommandStateMachine()

        _ = stateMachine.handleRightCommandDown()

        XCTAssertEqual(
            stateMachine.handleRightCommandUp(),
            .init(consumeOriginalEvent: true, sideEffects: [.handleRightCommandUpAction])
        )
    }

    func testRepeatedRightCommandDownWhileHeldDoesNotRetrigger() {
        var stateMachine = RightCommandStateMachine()

        _ = stateMachine.handleRightCommandDown()

        XCTAssertEqual(
            stateMachine.handleRightCommandDown(),
            .init(consumeOriginalEvent: true, sideEffects: [])
        )
    }

    func testOtherKeyActivityPassesThroughWhileHeld() {
        var stateMachine = RightCommandStateMachine()

        _ = stateMachine.handleRightCommandDown()

        XCTAssertEqual(
            stateMachine.handleOtherKeyActivity(),
            .init(consumeOriginalEvent: false, sideEffects: [])
        )
    }

    func testStrayRightCommandUpWhileIdlePassesThrough() {
        var stateMachine = RightCommandStateMachine()

        XCTAssertEqual(
            stateMachine.handleRightCommandUp(),
            .init(consumeOriginalEvent: false, sideEffects: [])
        )
    }
    func testResetClearsHeldStateAndPreventsFalseReleaseAction() {
        var stateMachine = RightCommandStateMachine()

        _ = stateMachine.handleRightCommandDown()
        stateMachine.reset()

        XCTAssertEqual(
            stateMachine.handleRightCommandUp(),
            .init(consumeOriginalEvent: false, sideEffects: [])
        )
    }
}