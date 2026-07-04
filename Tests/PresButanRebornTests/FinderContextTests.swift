import XCTest
@testable import PresButanReborn

final class StubFinderContext: FinderContextProviding {
    var frontmost = true
    var editing = false
    func isFinderFrontmost() -> Bool { frontmost }
    func isEditingText() -> Bool { editing }
}

final class FinderContextTests: XCTestCase {
    func testStubReportsInjectedState() {
        let stub = StubFinderContext()
        stub.frontmost = false
        stub.editing = true
        XCTAssertFalse(stub.isFinderFrontmost())
        XCTAssertTrue(stub.isEditingText())
    }

    func testRealContextDoesNotCrash() {
        // In headless CI there is no frontmost Finder; must simply return without crashing.
        let ctx = FinderContext()
        _ = ctx.isFinderFrontmost()
        _ = ctx.isEditingText()
    }
}
