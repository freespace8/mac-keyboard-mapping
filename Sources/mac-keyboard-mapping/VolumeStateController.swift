import Foundation

private struct VolumeSnapshot {
    let outputVolume: Int
    let outputMuted: Bool
}

final class VolumeStateController: @unchecked Sendable {
    private var snapshot: VolumeSnapshot?
    private var latestToken: UInt64 = 0

    @discardableResult
    func saveCurrentStateAndMute() -> UInt64 {
        latestToken &+= 1
        let token = latestToken

        guard let volume = readOutputVolume(), let muted = readOutputMuted() else {
            fputs("[rightcmd-agent] Failed to capture current volume state.\n", stderr)
            return token
        }

        snapshot = VolumeSnapshot(outputVolume: volume, outputMuted: muted)
        setOutputMuted(true)
        return token
    }

    func restoreSavedState(ifTokenMatches token: UInt64) {
        guard token == latestToken, let snapshot else {
            return
        }

        setOutputVolume(snapshot.outputVolume)
        setOutputMuted(snapshot.outputMuted)
    }

    var currentToken: UInt64 {
        latestToken
    }

    private func readOutputVolume() -> Int? {
        guard let descriptor = runAppleScript("output volume of (get volume settings)") else {
            return nil
        }

        return Int(descriptor.int32Value)
    }

    private func readOutputMuted() -> Bool? {
        guard let descriptor = runAppleScript("output muted of (get volume settings)") else {
            return nil
        }

        return descriptor.booleanValue
    }

    private func setOutputVolume(_ value: Int) {
        _ = runAppleScript("set volume output volume \(value)")
    }

    private func setOutputMuted(_ muted: Bool) {
        let flag = muted ? "true" : "false"
        _ = runAppleScript("set volume output muted \(flag)")
    }

    @discardableResult
    private func runAppleScript(_ source: String) -> NSAppleEventDescriptor? {
        guard let appleScript = NSAppleScript(source: source) else {
            fputs("[rightcmd-agent] Failed to create AppleScript: \(source)\n", stderr)
            return nil
        }

        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        if let error {
            fputs("[rightcmd-agent] AppleScript error: \(error) | script=\(source)\n", stderr)
        }
        return result
    }
}
