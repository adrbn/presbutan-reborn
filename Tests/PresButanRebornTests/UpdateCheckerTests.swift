import XCTest
@testable import PresButanReborn

final class UpdateCheckerTests: XCTestCase {
    func testIsNewerDetectsHigherVersions() {
        XCTAssertTrue(UpdateChecker.isNewer("v1.2.0", than: "1.1.0"))
        XCTAssertTrue(UpdateChecker.isNewer("v1.0.1", than: "1.0.0"))
        XCTAssertTrue(UpdateChecker.isNewer("2.0.0", than: "1.9.9"))
    }

    func testIsNewerFalseForEqualOrOlder() {
        XCTAssertFalse(UpdateChecker.isNewer("v1.0.0", than: "1.0.0"))
        XCTAssertFalse(UpdateChecker.isNewer("v0.9.0", than: "1.0.0"))
        XCTAssertFalse(UpdateChecker.isNewer("1.0", than: "1.0.0"))
    }

    func testEvaluate404IsNoReleases() {
        XCTAssertEqual(
            UpdateChecker.evaluate(current: "1.0.0", data: nil, status: 404, error: nil),
            .noReleases)
    }

    func testEvaluateParsesLatestTagAsUpdate() {
        let json = #"{"tag_name":"v1.5.0"}"#.data(using: .utf8)!
        XCTAssertEqual(
            UpdateChecker.evaluate(current: "1.0.0", data: json, status: 200, error: nil),
            .updateAvailable(latest: "1.5.0", current: "1.0.0"))
    }

    func testEvaluateSameVersionIsUpToDate() {
        let json = #"{"tag_name":"v1.0.0"}"#.data(using: .utf8)!
        XCTAssertEqual(
            UpdateChecker.evaluate(current: "1.0.0", data: json, status: 200, error: nil),
            .upToDate(current: "1.0.0"))
    }

    func testEvaluateNoStatusIsFailure() {
        if case .failed = UpdateChecker.evaluate(current: "1.0.0", data: nil, status: nil, error: nil) {
            // expected
        } else {
            XCTFail("expected .failed when there is no HTTP status")
        }
    }
}
