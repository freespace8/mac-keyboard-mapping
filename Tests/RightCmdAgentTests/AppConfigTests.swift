import XCTest
@testable import RightCmdAgent

final class AppConfigTests: XCTestCase {
    func testDecodingWithoutDelayUsesDefaultValue() throws {
        let json = """
        {
          "logKeyEvents": true
        }
        """

        let config = try JSONDecoder().decode(AppConfig.self, from: Data(json.utf8))

        XCTAssertTrue(config.logKeyEvents)
        XCTAssertEqual(
            config.rightCommandUpEnterDelayMilliseconds,
            AppConfig.defaultRightCommandUpEnterDelayMilliseconds
        )
    }

    func testDecodingWithDelayUsesConfiguredValue() throws {
        let json = """
        {
          "logKeyEvents": false,
          "rightCommandUpEnterDelayMilliseconds": 35
        }
        """

        let config = try JSONDecoder().decode(AppConfig.self, from: Data(json.utf8))

        XCTAssertFalse(config.logKeyEvents)
        XCTAssertEqual(config.rightCommandUpEnterDelayMilliseconds, 35)
    }
}
