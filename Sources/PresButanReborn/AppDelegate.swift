import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let context = FinderContext()
    private let poster = EventPoster()
    private lazy var keyTap = KeyTap(context: context, poster: poster)
    private var menu: MenuBarController?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menu = MenuBarController()
        Permissions.promptIfNeeded()
        startTapWhenTrusted()
    }

    private func startTapWhenTrusted() {
        if Permissions.isTrusted(), keyTap.start() {
            menu?.refresh()
            return
        }
        // Poll until the user grants Accessibility, then start the tap.
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self else { return }
            self.menu?.refresh()
            if Permissions.isTrusted(), self.keyTap.start() {
                timer.invalidate()
                self.menu?.refresh()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyTap.stop()
        permissionTimer?.invalidate()
    }
}
