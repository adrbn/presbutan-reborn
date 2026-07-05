import CoreGraphics
import os

protocol EventPosting {
    func post(_ keys: [SyntheticKey])
}

final class EventPoster: EventPosting {
    private let source = CGEventSource(stateID: .combinedSessionState)
    private let log = Logger(subsystem: "com.presbutanreborn.app", category: "EventPoster")

    func post(_ keys: [SyntheticKey]) {
        for key in keys {
            // Only emit the key-up if the key-down was posted, so we never
            // leave an unbalanced modifier (e.g. a stuck Command).
            guard emit(key, keyDown: true) else {
                log.error("failed to post key-down for keyCode \(key.keyCode, privacy: .public); skipping key-up")
                continue
            }
            if !emit(key, keyDown: false) {
                log.error("failed to post key-up for keyCode \(key.keyCode, privacy: .public)")
            }
        }
    }

    @discardableResult
    private func emit(_ key: SyntheticKey, keyDown: Bool) -> Bool {
        guard let event = CGEvent(keyboardEventSource: source,
                                  virtualKey: key.keyCode,
                                  keyDown: keyDown) else {
            return false
        }
        event.flags = key.flags
        event.setIntegerValueField(.eventSourceUserData, value: KeyTap.sentinel)
        event.post(tap: .cgSessionEventTap)
        return true
    }
}
