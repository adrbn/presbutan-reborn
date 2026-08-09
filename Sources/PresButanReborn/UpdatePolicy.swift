import Foundation

/// Decides *when* to check for updates and *whether* the result is worth
/// interrupting the user. Pure and unit-tested; the scheduling and networking
/// shells live in `UpdateScheduler` and `UpdateChecker`.
enum UpdatePolicy {
    static let checkInterval: TimeInterval = 24 * 60 * 60

    static func shouldCheck(now: Date,
                            lastCheck: Date?,
                            interval: TimeInterval = checkInterval) -> Bool {
        guard let lastCheck else { return true }
        // A clock that moved backwards would otherwise park the next check
        // arbitrarily far in the future.
        if lastCheck > now { return true }
        return now.timeIntervalSince(lastCheck) >= interval
    }

    /// A background check is silent by design: only a genuinely new version,
    /// one the user hasn't already dismissed, earns a dialog. Being up to date,
    /// having no releases, or failing to reach GitHub must never interrupt.
    static func shouldNotify(about outcome: UpdateChecker.Outcome,
                             skippedVersion: String?) -> Bool {
        guard case let .updateAvailable(latest, _) = outcome else { return false }
        return latest != skippedVersion
    }
}

/// Persisted state for background update checks.
struct UpdateSettings {
    private enum Key {
        static let lastCheck = "updateLastCheck"
        static let skippedVersion = "updateSkippedVersion"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastCheck: Date? {
        get { defaults.object(forKey: Key.lastCheck) as? Date }
        nonmutating set { defaults.set(newValue, forKey: Key.lastCheck) }
    }

    var skippedVersion: String? {
        get { defaults.string(forKey: Key.skippedVersion) }
        nonmutating set { defaults.set(newValue, forKey: Key.skippedVersion) }
    }
}
