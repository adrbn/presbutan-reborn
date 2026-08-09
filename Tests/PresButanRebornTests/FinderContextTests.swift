import AppKit
import XCTest
@testable import PresButanReborn

final class StubFinderContext: FinderContextProviding {
    var frontmost = true
    var editing = false
    var overlayFocused = false
    func isFinderFrontmost() -> Bool { frontmost }
    func isEditingText() -> Bool { editing }
    func overlayPanelHasKeyboardFocus() -> Bool { overlayFocused }
}

final class FinderContextTests: XCTestCase {
    func testStubReportsInjectedState() {
        let stub = StubFinderContext()
        stub.frontmost = false
        stub.editing = true
        stub.overlayFocused = true
        XCTAssertFalse(stub.isFinderFrontmost())
        XCTAssertTrue(stub.isEditingText())
        XCTAssertTrue(stub.overlayPanelHasKeyboardFocus())
    }

    func testRealContextDoesNotCrash() {
        // In headless CI there is no frontmost Finder; must simply return without crashing.
        let ctx = FinderContext()
        _ = ctx.isFinderFrontmost()
        _ = ctx.isEditingText()
        _ = ctx.overlayPanelHasKeyboardFocus()
    }

    /// With no frontmost application at all (headless CI), there is no keyboard
    /// owner to compare against — the check must not claim an overlay is focused,
    /// because that would silently disable the remap.
    func testOverlayCheckIsFalseWhenNothingIsFrontmost() {
        let ctx = FinderContext()
        if NSWorkspace.shared.frontmostApplication == nil {
            XCTAssertFalse(ctx.overlayPanelHasKeyboardFocus())
        }
    }
}
