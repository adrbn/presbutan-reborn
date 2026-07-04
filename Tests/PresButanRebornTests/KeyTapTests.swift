import XCTest
import CoreGraphics
@testable import PresButanReborn

final class KeyTapTests: XCTestCase {
    func testSyntheticEventsArePassedThrough() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: true, isRepeat: false,
                              keyCode: KeyCode.returnKey, flags: [],
                              finderFrontmost: true, editing: false)
        XCTAssertEqual(d, .passThrough)
    }

    func testNonFinderCandidatePassesThrough() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: false, isRepeat: false,
                              keyCode: KeyCode.delete, flags: [],
                              finderFrontmost: false, editing: false)
        XCTAssertEqual(d, .passThrough)
    }

    func testEditingCandidatePassesThrough() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: false, isRepeat: false,
                              keyCode: KeyCode.returnKey, flags: [],
                              finderFrontmost: true, editing: true)
        XCTAssertEqual(d, .passThrough)
    }

    func testFinderReturnRemaps() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: false, isRepeat: false,
                              keyCode: KeyCode.returnKey, flags: [],
                              finderFrontmost: true, editing: false)
        XCTAssertEqual(d, .remap([SyntheticKey(keyCode: KeyCode.letterO, flags: .maskCommand)]))
    }

    func testRepeatOfCandidateInFinderIsSwallowed() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: false, isRepeat: true,
                              keyCode: KeyCode.delete, flags: [],
                              finderFrontmost: true, editing: false)
        XCTAssertEqual(d, .swallow)
    }

    func testNonCandidateInFinderPassesThrough() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: false, isRepeat: false,
                              keyCode: 0, flags: [],
                              finderFrontmost: true, editing: false)
        XCTAssertEqual(d, .passThrough)
    }
}
