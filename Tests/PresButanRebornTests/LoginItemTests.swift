import XCTest
@testable import PresButanReborn

final class LoginItemTests: XCTestCase {
    func testIsEnabledReturnsBoolWithoutCrashing() {
        let value: Bool = LoginItem.isEnabled
        XCTAssertTrue(value == true || value == false)
    }
}
