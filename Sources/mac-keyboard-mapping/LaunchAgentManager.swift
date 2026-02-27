import Foundation

enum LaunchAgentManagerError: Error {
    case executablePathMissing
    case commandFailed(String)
}

final class LaunchAgentManager {
    static let label = "com.freespace8.rightcmd.agent"

    private let fileManager = FileManager.default

    private var guiDomain: String {
        "gui/\(Int(getuid()))"
    }

    private var plistURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/LaunchAgents")
            .appendingPathComponent("\(Self.label).plist")
    }

    private var logDirectoryURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Logs/rightcmd-agent")
    }

    func isEnabled() -> Bool {
        fileManager.fileExists(atPath: plistURL.path)
    }

    func setEnabled(_ enabled: Bool, executablePath: String, configPath: String) throws {
        if enabled {
            try enable(executablePath: executablePath, configPath: configPath)
        } else {
            try disable()
        }
    }

    private func enable(executablePath: String, configPath: String) throws {
        guard !executablePath.isEmpty else {
            throw LaunchAgentManagerError.executablePathMissing
        }

        let expandedConfigPath = (configPath as NSString).expandingTildeInPath

        let launchAgentsDir = plistURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true)

        let configDir = URL(fileURLWithPath: expandedConfigPath).deletingLastPathComponent()
        try fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)

        let stdoutPath = logDirectoryURL.appendingPathComponent("stdout.log").path
        let stderrPath = logDirectoryURL.appendingPathComponent("stderr.log").path

        let plist = renderPlist(
            executablePath: executablePath,
            configPath: expandedConfigPath,
            stdoutPath: stdoutPath,
            stderrPath: stderrPath
        )

        try plist.write(to: plistURL, atomically: true, encoding: .utf8)

        _ = try runLaunchctl(["enable", "\(guiDomain)/\(Self.label)"], allowFailure: true)
    }

    private func disable() throws {
        _ = try runLaunchctl(["bootout", guiDomain, plistURL.path], allowFailure: true)

        if fileManager.fileExists(atPath: plistURL.path) {
            try fileManager.removeItem(at: plistURL)
        }
    }

    private func runLaunchctl(_ arguments: [String], allowFailure: Bool) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0, !allowFailure {
            let command = (["launchctl"] + arguments).joined(separator: " ")
            throw LaunchAgentManagerError.commandFailed("\(command)\n\(output)")
        }

        return output
    }

    private func renderPlist(
        executablePath: String,
        configPath: String,
        stdoutPath: String,
        stderrPath: String
    ) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(Self.label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(xmlEscaped(executablePath))</string>
            </array>
            <key>EnvironmentVariables</key>
            <dict>
                <key>RIGHTCMD_CONFIG</key>
                <string>\(xmlEscaped(configPath))</string>
            </dict>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>\(xmlEscaped(stdoutPath))</string>
            <key>StandardErrorPath</key>
            <string>\(xmlEscaped(stderrPath))</string>
        </dict>
        </plist>
        """
    }

    private func xmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
