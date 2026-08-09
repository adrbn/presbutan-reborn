import AppKit
import os

/// Runs update checks in the background: once shortly after launch, then at most
/// once a day, staying completely silent unless a new version is actually out.
///
/// Without this, `UpdateChecker` only ever ran from the menu item, so anyone who
/// installed an older build was never told a fix existed — and users who hid the
/// menu-bar icon had no way to ask at all.
final class UpdateScheduler {
    /// Long enough to stay out of the way of the Accessibility prompt on first run.
    private static let launchDelay: TimeInterval = 15
    /// Coarse tick; `UpdatePolicy` owns the real once-a-day rule, which survives
    /// relaunches because the last-check date is persisted.
    private static let tickInterval: TimeInterval = 60 * 60

    private let settings: UpdateSettings
    private let log = Logger(subsystem: "com.presbutanreborn.app", category: "UpdateScheduler")
    private var timer: Timer?
    private var isChecking = false

    init(settings: UpdateSettings = UpdateSettings()) {
        self.settings = settings
    }

    func start() {
        stop()
        let timer = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            self?.checkIfDue()
        }
        timer.tolerance = 60 * 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.launchDelay) { [weak self] in
            self?.checkIfDue()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkIfDue() {
        guard !isChecking else { return }
        guard UpdatePolicy.shouldCheck(now: Date(), lastCheck: settings.lastCheck) else { return }
        isChecking = true

        UpdateChecker.fetchOutcome { [weak self] outcome in
            guard let self else { return }
            self.isChecking = false

            // Record the attempt even on failure, so a GitHub outage or an
            // offline laptop cannot turn into a request every hour.
            self.settings.lastCheck = Date()

            guard UpdatePolicy.shouldNotify(about: outcome, skippedVersion: self.settings.skippedVersion),
                  case let .updateAvailable(latest, current) = outcome else { return }

            self.log.info("update \(latest, privacy: .public) available")
            if UpdateChecker.presentBackgroundUpdate(latest: latest, current: current) == .skipVersion {
                self.settings.skippedVersion = latest
            }
        }
    }
}
