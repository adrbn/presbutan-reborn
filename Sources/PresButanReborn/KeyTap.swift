import CoreGraphics
import CoreFoundation

enum TapDecision: Equatable {
    case passThrough
    case swallow
    case remap([SyntheticKey])
}

final class KeyTap {
    /// Sentinel written into `.eventSourceUserData` on our own synthetic events
    /// so the tap never re-processes what it just posted. "PBR\0".
    static let sentinel: Int64 = 0x5042_5200

    private let context: FinderContextProviding
    private let poster: EventPosting
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(context: FinderContextProviding, poster: EventPosting) {
        self.context = context
        self.poster = poster
    }

    /// Pure decision logic, unit-tested in isolation.
    static func decide(type: CGEventType,
                       isSynthetic: Bool,
                       isRepeat: Bool,
                       keyCode: CGKeyCode,
                       flags: CGEventFlags,
                       finderFrontmost: Bool,
                       editing: Bool) -> TapDecision {
        guard type == .keyDown else { return .passThrough }
        if isSynthetic { return .passThrough }

        guard case let .send(keys) = Remap.action(forKeyCode: keyCode, flags: flags) else {
            return .passThrough
        }
        // Only after confirming this is a remap candidate do we consult Finder state,
        // so normal typing never triggers an Accessibility read.
        guard finderFrontmost, !editing else { return .passThrough }
        if isRepeat { return .swallow }
        return .remap(keys)
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: KeyTap.cCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        return true
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private static let cCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let tap = Unmanaged<KeyTap>.fromOpaque(refcon).takeUnretainedValue()
        return tap.handle(type: type, event: event)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let isSynthetic = event.getIntegerValueField(.eventSourceUserData) == KeyTap.sentinel
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        // Cheap pre-check so we only pay for Accessibility reads on candidate keys.
        let isCandidate: Bool
        if case .send = Remap.action(forKeyCode: keyCode, flags: event.flags) {
            isCandidate = true
        } else {
            isCandidate = false
        }
        let frontmost = (isCandidate && !isSynthetic) ? context.isFinderFrontmost() : false
        let editing = frontmost ? context.isEditingText() : false

        switch KeyTap.decide(type: type, isSynthetic: isSynthetic, isRepeat: isRepeat,
                             keyCode: keyCode, flags: event.flags,
                             finderFrontmost: frontmost, editing: editing) {
        case .passThrough:
            return Unmanaged.passUnretained(event)
        case .swallow:
            return nil
        case .remap(let keys):
            poster.post(keys)
            return nil
        }
    }
}
