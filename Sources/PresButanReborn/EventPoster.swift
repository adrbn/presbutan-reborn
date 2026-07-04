import CoreGraphics

protocol EventPosting {
    func post(_ keys: [SyntheticKey])
}

final class EventPoster: EventPosting {
    private let source = CGEventSource(stateID: .combinedSessionState)

    func post(_ keys: [SyntheticKey]) {
        for key in keys {
            emit(key, keyDown: true)
            emit(key, keyDown: false)
        }
    }

    private func emit(_ key: SyntheticKey, keyDown: Bool) {
        guard let event = CGEvent(keyboardEventSource: source,
                                  virtualKey: key.keyCode,
                                  keyDown: keyDown) else { return }
        event.flags = key.flags
        event.setIntegerValueField(.eventSourceUserData, value: KeyTap.sentinel)
        event.post(tap: .cgSessionEventTap)
    }
}
