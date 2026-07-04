import CoreGraphics

enum KeyCode {
    static let returnKey: CGKeyCode = 36
    static let keypadEnter: CGKeyCode = 76
    static let delete: CGKeyCode = 51
    static let forwardDelete: CGKeyCode = 117
    static let letterO: CGKeyCode = 31
}

struct SyntheticKey: Equatable {
    let keyCode: CGKeyCode
    let flags: CGEventFlags

    static func == (lhs: SyntheticKey, rhs: SyntheticKey) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.flags.rawValue == rhs.flags.rawValue
    }
}

enum RemapAction: Equatable {
    case passThrough
    case send([SyntheticKey])
}

enum Remap {
    private static let significant: CGEventFlags =
        [.maskCommand, .maskShift, .maskControl, .maskAlternate]

    static func action(forKeyCode keyCode: CGKeyCode, flags: CGEventFlags) -> RemapAction {
        let mods = flags.intersection(significant)

        switch keyCode {
        case KeyCode.returnKey, KeyCode.keypadEnter:
            guard mods.isEmpty else { return .passThrough }
            return .send([SyntheticKey(keyCode: KeyCode.letterO, flags: .maskCommand)])

        case KeyCode.delete, KeyCode.forwardDelete:
            if mods.isEmpty {
                return .send([SyntheticKey(keyCode: KeyCode.delete, flags: .maskCommand)])
            } else if mods == .maskShift {
                return .send([SyntheticKey(keyCode: KeyCode.delete,
                                           flags: [.maskCommand, .maskAlternate])])
            } else {
                return .passThrough
            }

        default:
            return .passThrough
        }
    }
}
