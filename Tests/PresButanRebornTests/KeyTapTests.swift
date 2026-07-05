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

final class CapturingPoster: EventPosting {
    var posted: [[SyntheticKey]] = []
    func post(_ keys: [SyntheticKey]) { posted.append(keys) }
}

extension KeyTapTests {
    func testHandlePassesThroughSyntheticEventWithoutReposting() {
        let poster = CapturingPoster()
        let ctx = StubFinderContext(); ctx.frontmost = true; ctx.editing = false
        let tap = KeyTap(context: ctx, poster: poster)
        let src = CGEventSource(stateID: .combinedSessionState)
        let ev = CGEvent(keyboardEventSource: src, virtualKey: KeyCode.returnKey, keyDown: true)!
        ev.flags = []
        ev.setIntegerValueField(.eventSourceUserData, value: KeyTap.sentinel)
        let result = tap.handle(type: .keyDown, event: ev)
        XCTAssertNotNil(result, "synthetic (sentinel-tagged) events must pass through")
        XCTAssertEqual(poster.posted.count, 0, "synthetic events must not be re-posted")
    }

    func testHandleRemapsBareReturnInFinder() {
        let poster = CapturingPoster()
        let ctx = StubFinderContext(); ctx.frontmost = true; ctx.editing = false
        let tap = KeyTap(context: ctx, poster: poster)
        let src = CGEventSource(stateID: .combinedSessionState)
        let ev = CGEvent(keyboardEventSource: src, virtualKey: KeyCode.returnKey, keyDown: true)!
        ev.flags = []
        ev.setIntegerValueField(.eventSourceUserData, value: 0)
        let result = tap.handle(type: .keyDown, event: ev)
        XCTAssertNil(result, "a bare Return in Finder (not editing) must be swallowed")
        XCTAssertEqual(poster.posted, [[SyntheticKey(keyCode: KeyCode.letterO, flags: .maskCommand)]],
                       "a bare Return must post exactly one Cmd-O")
    }
}
