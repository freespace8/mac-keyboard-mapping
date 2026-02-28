import AppKit
import XCTest
@testable import RightCmdAgent

final class ClipboardStateControllerTests: XCTestCase {
    func testRestoreSavedStateRestoresOriginalStringContent() {
        let pasteboard = makeUniquePasteboard()
        setString("before", in: pasteboard)
        let controller = ClipboardStateController(pasteboard: pasteboard)

        let token = controller.saveCurrentState()
        setString("after", in: pasteboard)

        controller.restoreSavedState(ifTokenMatches: token)

        XCTAssertEqual(pasteboard.string(forType: .string), "before")
    }

    func testRestoreWithStaleTokenDoesNotOverwriteCurrentClipboard() {
        let pasteboard = makeUniquePasteboard()
        setString("first", in: pasteboard)
        let controller = ClipboardStateController(pasteboard: pasteboard)

        let staleToken = controller.saveCurrentState()
        setString("second", in: pasteboard)
        let validToken = controller.saveCurrentState()

        setString("third", in: pasteboard)
        controller.restoreSavedState(ifTokenMatches: staleToken)

        XCTAssertEqual(pasteboard.string(forType: .string), "third")

        controller.restoreSavedState(ifTokenMatches: validToken)

        XCTAssertEqual(pasteboard.string(forType: .string), "second")
    }

    func testRestoreSavedEmptyClipboardClearsClipboard() {
        let pasteboard = makeUniquePasteboard()
        pasteboard.clearContents()
        let controller = ClipboardStateController(pasteboard: pasteboard)

        let token = controller.saveCurrentState()
        setString("temporary", in: pasteboard)

        controller.restoreSavedState(ifTokenMatches: token)

        XCTAssertNil(pasteboard.string(forType: .string))
    }

    private func makeUniquePasteboard() -> NSPasteboard {
        let name = NSPasteboard.Name("com.freespace8.rightcmd.tests.\(UUID().uuidString)")
        return NSPasteboard(name: name)
    }

    private func setString(_ value: String, in pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.setString(value, forType: .string))
    }
}
