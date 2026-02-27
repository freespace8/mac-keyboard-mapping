import Foundation

enum RightCmdServiceError: Error {
    case eventSynthesizerUnavailable
    case eventTapStartFailed(Error)
}

final class RightCmdService {
    private let tapManager: EventTapManager

    init(config: AppConfig) throws {
        guard let synthesizer = EventSynthesizer() else {
            throw RightCmdServiceError.eventSynthesizerUnavailable
        }

        let stateMachine = RightCommandStateMachine()
        let volumeController = VolumeStateController()
        let actionQueue = DispatchQueue(label: "com.freespace8.rightcmd.side-effects")
        let enterDelayMilliseconds = Int(
            min(config.rightCommandUpEnterDelayMilliseconds, UInt64(Int.max))
        )
        let restoreDelayMilliseconds = 100
        tapManager = EventTapManager(
            stateMachine: stateMachine,
            logKeyEvents: config.logKeyEvents
        ) { sideEffects in
            actionQueue.async {
                for effect in sideEffects {
                    switch effect {
                    case .handleRightCommandDownAction:
                        _ = volumeController.saveCurrentStateAndMute()
                        synthesizer.emitLeftCommandOne()
                    case .handleRightCommandUpAction:
                        let token = volumeController.currentToken
                        actionQueue.asyncAfter(deadline: .now() + .milliseconds(enterDelayMilliseconds)) {
                            synthesizer.emitReturnOrEnter()
                            actionQueue.asyncAfter(deadline: .now() + .milliseconds(restoreDelayMilliseconds)) {
                                volumeController.restoreSavedState(ifTokenMatches: token)
                            }
                        }
                    }
                }
            }
        }
    }

    func start() throws {
        do {
            try tapManager.start()
        } catch {
            throw RightCmdServiceError.eventTapStartFailed(error)
        }
    }

    func stop() {
        tapManager.stop()
    }

    var modeText: String {
        "right_command down: cmd+1; up: return + restore volume"
    }

}