import XCTest
@testable import PresButanReborn

final class UpdatePolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - When to check

    func testFirstRunChecksImmediately() {
        XCTAssertTrue(UpdatePolicy.shouldCheck(now: now, lastCheck: nil))
    }

    func testDoesNotRecheckWithinTheInterval() {
        let recent = now.addingTimeInterval(-UpdatePolicy.checkInterval + 60)
        XCTAssertFalse(UpdatePolicy.shouldCheck(now: now, lastCheck: recent))
    }

    func testRechecksOnceTheIntervalHasElapsed() {
        let stale = now.addingTimeInterval(-UpdatePolicy.checkInterval)
        XCTAssertTrue(UpdatePolicy.shouldCheck(now: now, lastCheck: stale))
    }

    /// A clock that jumped backwards (timezone fix, NTP correction) would otherwise
    /// park the next check arbitrarily far in the future.
    func testClockMovedBackwardsDoesNotPostponeChecksForever() {
        let future = now.addingTimeInterval(60 * 60 * 24 * 365)
        XCTAssertTrue(UpdatePolicy.shouldCheck(now: now, lastCheck: future))
    }

    // MARK: - When to interrupt the user

    func testNotifiesWhenAnUpdateIsAvailable() {
        let outcome = UpdateChecker.Outcome.updateAvailable(latest: "1.1.0", current: "1.0.0")
        XCTAssertTrue(UpdatePolicy.shouldNotify(about: outcome, skippedVersion: nil))
    }

    /// Silence is the whole point of a background check: being up to date, having
    /// no releases, or failing to reach GitHub must never raise a dialog.
    func testStaysSilentForEveryNonUpdateOutcome() {
        let quiet: [UpdateChecker.Outcome] = [
            .upToDate(current: "1.0.0"),
            .noReleases,
            .failed("offline"),
        ]
        for outcome in quiet {
            XCTAssertFalse(UpdatePolicy.shouldNotify(about: outcome, skippedVersion: nil),
                           "\(outcome) must not interrupt the user")
        }
    }

    func testDoesNotNagAboutASkippedVersion() {
        let outcome = UpdateChecker.Outcome.updateAvailable(latest: "1.1.0", current: "1.0.0")
        XCTAssertFalse(UpdatePolicy.shouldNotify(about: outcome, skippedVersion: "1.1.0"))
    }

    func testSkippingOneVersionDoesNotSuppressTheNext() {
        let outcome = UpdateChecker.Outcome.updateAvailable(latest: "1.2.0", current: "1.0.0")
        XCTAssertTrue(UpdatePolicy.shouldNotify(about: outcome, skippedVersion: "1.1.0"))
    }
}

final class UpdateSettingsTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "PBRTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testStartsEmpty() {
        let settings = UpdateSettings(defaults: defaults)
        XCTAssertNil(settings.lastCheck)
        XCTAssertNil(settings.skippedVersion)
    }

    func testRoundTripsBothValues() {
        let settings = UpdateSettings(defaults: defaults)
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        settings.lastCheck = stamp
        settings.skippedVersion = "1.4.2"

        let reloaded = UpdateSettings(defaults: defaults)
        XCTAssertEqual(reloaded.lastCheck, stamp)
        XCTAssertEqual(reloaded.skippedVersion, "1.4.2")
    }
}
