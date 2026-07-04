import XCTest
import CoreGraphics
@testable import PresButanReborn

final class RemapTests: XCTestCase {
    private let cmd: CGEventFlags = .maskCommand
    private let cmdOpt: CGEventFlags = [.maskCommand, .maskAlternate]

    func testReturnMapsToCommandO() {
        XCTAssertEqual(
            Remap.action(forKeyCode: KeyCode.returnKey, flags: []),
            .send([SyntheticKey(keyCode: KeyCode.letterO, flags: cmd)])
        )
    }

    func testKeypadEnterMapsToCommandO() {
        // Keypad Enter often carries the numeric-pad flag; it must be ignored.
        XCTAssertEqual(
            Remap.action(forKeyCode: KeyCode.keypadEnter, flags: .maskNumericPad),
            .send([SyntheticKey(keyCode: KeyCode.letterO, flags: cmd)])
        )
    }

    func testDeleteMapsToCommandDelete() {
        XCTAssertEqual(
            Remap.action(forKeyCode: KeyCode.delete, flags: []),
            .send([SyntheticKey(keyCode: KeyCode.delete, flags: cmd)])
        )
    }

    func testForwardDeleteMapsToCommandDelete() {
        XCTAssertEqual(
            Remap.action(forKeyCode: KeyCode.forwardDelete, flags: []),
            .send([SyntheticKey(keyCode: KeyCode.delete, flags: cmd)])
        )
    }

    func testShiftDeleteMapsToDeleteImmediately() {
        XCTAssertEqual(
            Remap.action(forKeyCode: KeyCode.delete, flags: .maskShift),
            .send([SyntheticKey(keyCode: KeyCode.delete, flags: cmdOpt)])
        )
    }

    func testCapsLockIsIgnoredOnReturn() {
        XCTAssertEqual(
            Remap.action(forKeyCode: KeyCode.returnKey, flags: .maskAlphaShift),
            .send([SyntheticKey(keyCode: KeyCode.letterO, flags: cmd)])
        )
    }

    func testCommandReturnPassesThrough() {
        XCTAssertEqual(Remap.action(forKeyCode: KeyCode.returnKey, flags: .maskCommand), .passThrough)
    }

    func testOptionDeletePassesThrough() {
        XCTAssertEqual(Remap.action(forKeyCode: KeyCode.delete, flags: .maskAlternate), .passThrough)
    }

    func testLetterKeyPassesThrough() {
        // 'A' == keyCode 0
        XCTAssertEqual(Remap.action(forKeyCode: 0, flags: []), .passThrough)
    }
}
