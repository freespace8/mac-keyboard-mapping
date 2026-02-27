import Foundation

struct AppConfig: Decodable {
    static let defaultPath = "~/Library/Application Support/RightCmdAgent/config.json"
    static let defaultRightCommandUpEnterDelayMilliseconds: UInt64 = 16

    var logKeyEvents: Bool = false
    var rightCommandUpEnterDelayMilliseconds: UInt64 = defaultRightCommandUpEnterDelayMilliseconds

    private enum CodingKeys: String, CodingKey {
        case logKeyEvents
        case rightCommandUpEnterDelayMilliseconds
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        logKeyEvents = try container.decodeIfPresent(Bool.self, forKey: .logKeyEvents) ?? false
        rightCommandUpEnterDelayMilliseconds = try container.decodeIfPresent(
            UInt64.self,
            forKey: .rightCommandUpEnterDelayMilliseconds
        ) ?? Self.defaultRightCommandUpEnterDelayMilliseconds
    }

    static func load() -> AppConfig {
        let path = resolvedPath()
        let expandedPath = (path as NSString).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            return AppConfig()
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: expandedPath))
            return try JSONDecoder().decode(AppConfig.self, from: data)
        } catch {
            fputs("[rightcmd-agent] Failed to load config at \(expandedPath): \(error)\n", stderr)
            return AppConfig()
        }
    }

    static func resolvedPath() -> String {
        resolveConfigPath()
    }

    private static func resolveConfigPath() -> String {
        if let path = ProcessInfo.processInfo.environment["RIGHTCMD_CONFIG"], !path.isEmpty {
            return path
        }
        return defaultPath
    }
}