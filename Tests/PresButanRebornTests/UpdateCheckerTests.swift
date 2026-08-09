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

    /// The other tests feed a one-key stub. This one uses the real shape GitHub
    /// returns for this repository, so a payload change is caught here rather
    /// than by users silently never being offered an update.
    func testEvaluateHandlesRealGitHubPayloadShape() {
        let json = """
        {
          "url": "https://api.github.com/repos/adrbn/presbutan-reborn/releases/1",
          "assets": [
            {"name": "PresButanReborn.dmg", "state": "uploaded", "download_count": 0}
          ],
          "tag_name": "v1.0.0",
          "target_commitish": "main",
          "name": "v1.0.0",
          "draft": false,
          "prerelease": false,
          "author": {"login": "adrbn", "id": 1}
        }
        """.data(using: .utf8)!

        XCTAssertEqual(
            UpdateChecker.evaluate(current: "0.9.0", data: json, status: 200, error: nil),
            .updateAvailable(latest: "1.0.0", current: "0.9.0"))
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
