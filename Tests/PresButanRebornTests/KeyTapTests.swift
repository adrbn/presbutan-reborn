import XCTest
import CoreGraphics
@testable import PresButanReborn

final class KeyTapTests: XCTestCase {
    func testSyntheticEventsArePassedThrough() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: true, isRepeat: false,
                              keyCode: KeyCode.returnKey, flags: [],
                              finderFrontmost: true, editing: false, overlayFocused: false)
        XCTAssertEqual(d, .passThrough)
    }

    func testNonFinderCandidatePassesThrough() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: false, isRepeat: false,
                              keyCode: KeyCode.delete, flags: [],
                              finderFrontmost: false, editing: false, overlayFocused: false)
        XCTAssertEqual(d, .passThrough)
    }

    func testEditingCandidatePassesThrough() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: false, isRepeat: false,
                              keyCode: KeyCode.returnKey, flags: [],
                              finderFrontmost: true, editing: true, overlayFocused: false)
        XCTAssertEqual(d, .passThrough)
    }

    func testFinderReturnRemaps() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: false, isRepeat: false,
                              keyCode: KeyCode.returnKey, flags: [],
                              finderFrontmost: true, editing: false, overlayFocused: false)
        XCTAssertEqual(d, .remap([SyntheticKey(keyCode: KeyCode.letterO, flags: .maskCommand)]))
    }

    func testRepeatOfCandidateInFinderIsSwallowed() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: false, isRepeat: true,
                              keyCode: KeyCode.delete, flags: [],
                              finderFrontmost: true, editing: false, overlayFocused: false)
        XCTAssertEqual(d, .swallow)
    }

    func testNonCandidateInFinderPassesThrough() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: false, isRepeat: false,
                              keyCode: 0, flags: [],
                              finderFrontmost: true, editing: false, overlayFocused: false)
        XCTAssertEqual(d, .passThrough)
    }

    // MARK: - Overlay panels (Spotlight, Raycast, Alfred…)

    /// Spotlight is a non-activating panel: it takes the keyboard while
    /// `NSWorkspace.frontmostApplication` still reports Finder. Return must reach
    /// Spotlight untouched, or it never opens the highlighted result.
    func testReturnPassesThroughWhenOverlayPanelOwnsKeyboard() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: false, isRepeat: false,
                              keyCode: KeyCode.returnKey, flags: [],
                              finderFrontmost: true, editing: false, overlayFocused: true)
        XCTAssertEqual(d, .passThrough)
    }

    /// The same panel also broke Delete, which was being turned into Cmd-Delete.
    func testDeletePassesThroughWhenOverlayPanelOwnsKeyboard() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: false, isRepeat: false,
                              keyCode: KeyCode.delete, flags: [],
                              finderFrontmost: true, editing: false, overlayFocused: true)
        XCTAssertEqual(d, .passThrough)
    }

    /// Autorepeat must not be swallowed either — holding Delete in a Spotlight
    /// query has to keep erasing characters.
    func testRepeatPassesThroughWhenOverlayPanelOwnsKeyboard() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: false, isRepeat: true,
                              keyCode: KeyCode.delete, flags: [],
                              finderFrontmost: true, editing: false, overlayFocused: true)
        XCTAssertEqual(d, .passThrough)
    }

    func testKeypadEnterPassesThroughWhenOverlayPanelOwnsKeyboard() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: false, isRepeat: false,
                              keyCode: KeyCode.keypadEnter, flags: [],
                              finderFrontmost: true, editing: false, overlayFocused: true)
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

    /// End-to-end guard for the Spotlight bug: the event must survive the tap
    /// untouched and no Cmd-O may be posted in its place.
    func testHandlePassesReturnThroughWhenOverlayPanelOwnsKeyboard() {
        let poster = CapturingPoster()
        let ctx = StubFinderContext()
        ctx.frontmost = true          // Finder still owns the menu bar…
        ctx.editing = false
        ctx.overlayFocused = true     // …but Spotlight owns the keyboard.
        let tap = KeyTap(context: ctx, poster: poster)
        let src = CGEventSource(stateID: .combinedSessionState)
        let ev = CGEvent(keyboardEventSource: src, virtualKey: KeyCode.returnKey, keyDown: true)!
        ev.flags = []
        ev.setIntegerValueField(.eventSourceUserData, value: 0)
        let result = tap.handle(type: .keyDown, event: ev)
        XCTAssertNotNil(result, "Return must reach Spotlight so it can open the result")
        XCTAssertEqual(poster.posted.count, 0, "no Cmd-O may be posted at a Spotlight panel")
    }
}
