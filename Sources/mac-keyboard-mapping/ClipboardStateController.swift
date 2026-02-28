import AppKit
import Foundation

private struct ClipboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]
}

final class ClipboardStateController: @unchecked Sendable {
    private let pasteboard: NSPasteboard
    private var snapshot: ClipboardSnapshot?
    private var latestToken: UInt64 = 0

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    @discardableResult
    func saveCurrentState() -> UInt64 {
        latestToken &+= 1
        let token = latestToken

        let copiedItems = (pasteboard.pasteboardItems ?? []).map { item in
            var copiedData: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    copiedData[type] = data
                }
            }
            return copiedData
        }

        snapshot = ClipboardSnapshot(items: copiedItems)
        return token
    }

    func restoreSavedState(ifTokenMatches token: UInt64) {
        guard token == latestToken, let snapshot else {
            return
        }

        pasteboard.clearContents()
        guard !snapshot.items.isEmpty else {
            return
        }

        let restoredItems = snapshot.items.map { itemData -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            return item
        }

        if !pasteboard.writeObjects(restoredItems) {
            fputs("[rightcmd-agent] Failed to restore clipboard state.\n", stderr)
        }
    }

    var currentToken: UInt64 {
        latestToken
    }
}
