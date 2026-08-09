import AppKit
import Foundation

/// Checks GitHub Releases for a newer version and reports the result via an alert.
///
/// The network call is a thin shell; the decision logic (`evaluate`, `isNewer`)
/// is pure and unit-tested. Note: this only finds releases once the repository
/// is public and has at least one published release.
enum UpdateChecker {
    static let repository = "adrbn/presbutan-reborn"
    static let repositoryURL = URL(string: "https://github.com/\(repository)")!
    static let releasesPageURL = URL(string: "https://github.com/\(repository)/releases/latest")!
    private static let latestReleaseAPI =
        URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!

    /// Current app version from the bundle (falls back to "0.0.0" for unbundled runs).
    static var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }

    /// Fetches the latest release and reports the outcome on the main queue.
    /// Shared by the menu item and the background scheduler.
    static func fetchOutcome(completion: @escaping (Outcome) -> Void) {
        var request = URLRequest(url: latestReleaseAPI)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        let current = currentVersion
        URLSession.shared.dataTask(with: request) { data, response, error in
            let outcome = evaluate(current: current, data: data,
                                   status: (response as? HTTPURLResponse)?.statusCode,
                                   error: error)
            DispatchQueue.main.async { completion(outcome) }
        }.resume()
    }

    /// Fetches the latest release and shows an alert (up-to-date / update available / error).
    /// Always reports something — the user asked, so silence would look broken.
    static func checkInteractively() {
        fetchOutcome { present($0) }
    }

    // MARK: - Pure logic (unit-tested)

    enum Outcome: Equatable {
        case upToDate(current: String)
        case updateAvailable(latest: String, current: String)
        case noReleases
        case failed(String)
    }

    static func evaluate(current: String, data: Data?, status: Int?, error: Error?) -> Outcome {
        if let error = error { return .failed(error.localizedDescription) }
        switch status {
        case 200:
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else {
                return .failed("Unexpected response from GitHub.")
            }
            return isNewer(tag, than: current)
                ? .updateAvailable(latest: normalize(tag), current: current)
                : .upToDate(current: current)
        case 404:
            return .noReleases
        case .some(let code):
            return .failed("GitHub returned HTTP \(code).")
        case .none:
            return .failed("No response from GitHub.")
        }
    }

    /// True when `tag` (e.g. "v1.2.0") represents a newer version than `current`.
    static func isNewer(_ tag: String, than current: String) -> Bool {
        let a = components(tag), b = components(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private static func normalize(_ tag: String) -> String {
        tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
    }

    private static func components(_ version: String) -> [Int] {
        normalize(version).split(separator: ".").map { part in
            Int(part.prefix { $0.isNumber }) ?? 0
        }
    }

    // MARK: - Presentation

    enum UpdateResponse { case viewRelease, skipVersion, later }

    /// Alert for a background-discovered update. Unlike the interactive path this
    /// offers "Skip This Version", so the user can silence a release for good.
    static func presentBackgroundUpdate(latest: String, current: String) -> UpdateResponse {
        // A menu-bar accessory is not the active app when the timer fires, so the
        // alert would otherwise open behind whatever the user is working in.
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Update available"
        alert.informativeText = "PresButan Reborn \(latest) is available (you have \(current))."
        alert.addButton(withTitle: "View Release")
        alert.addButton(withTitle: "Skip This Version")
        alert.addButton(withTitle: "Later")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.open(releasesPageURL)
            return .viewRelease
        case .alertSecondButtonReturn:
            return .skipVersion
        default:
            return .later
        }
    }

    private static func present(_ outcome: Outcome) {
        let alert = NSAlert()
        switch outcome {
        case .upToDate(let current):
            alert.messageText = "You're up to date"
            alert.informativeText = "PresButan Reborn \(current) is the latest version."
            alert.runModal()
        case .updateAvailable(let latest, let current):
            alert.messageText = "Update available"
            alert.informativeText = "PresButan Reborn \(latest) is available (you have \(current))."
            alert.addButton(withTitle: "View Release")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(releasesPageURL)
            }
        case .noReleases:
            alert.messageText = "No releases yet"
            alert.informativeText = "There are no published releases to compare against."
            alert.runModal()
        case .failed(let reason):
            alert.messageText = "Couldn't check for updates"
            alert.informativeText = reason
            alert.runModal()
        }
    }
}
