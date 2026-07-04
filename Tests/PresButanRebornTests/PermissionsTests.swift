import XCTest
@testable import PresButanReborn

final class PermissionsTests: XCTestCase {
    func testAccessibilitySettingsURLIsCorrect() {
        XCTAssertEqual(
            Permissions.accessibilitySettingsURL.absoluteString,
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )
    }

    func testIsTrustedReturnsBoolWithoutCrashing() {
        _ = Permissions.isTrusted()
    }
}
