import AppKit
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let context = FinderContext()
    private let poster = EventPoster()
    private lazy var keyTap = KeyTap(context: context, poster: poster)
    private var menu: MenuBarController?
    private let updates = UpdateScheduler()
    private var permissionTimer: Timer?
    private var didCompleteLaunch = false
    private let log = OSLog(subsystem: "com.presbutanreborn.app", category: "launch")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // If a second instance was forced (e.g. `open -n`), ask the
        // already-running instance to reveal its menu-bar icon and quit. This
        // is the fallback path; the common "reopen the .app" case is handled
        // by applicationDidBecomeActive / applicationShouldHandleReopen below.
        if anotherInstanceIsRunning() {
            log("Second instance detected — forwarding show-icon request, then quitting.")
            DistributedNotificationCenter.default().postNotificationName(
                MenuBarController.showIconNotification,
                object: nil,
                options: [.deliverImmediately]
            )
            NSApp.terminate(nil)
            return
        }

        menu = MenuBarController()
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(showMenuBarIcon),
            name: MenuBarController.showIconNotification, object: nil
        )
        Permissions.promptIfNeeded()
        startTapWhenTrusted()
        updates.start()
        didCompleteLaunch = true
    }

    /// Reactivation path (the common case): when the user double-clicks the
    /// .app in Finder or Spotlight while it's already running, LaunchServices
    /// activates the existing instance rather than spawning a new process —
    /// so applicationDidFinishLaunching does NOT fire again. We catch it here.
    func applicationDidBecomeActive(_ notification: Notification) {
        guard didCompleteLaunch else { return }   // skip the first activation
        guard let menu, !menu.isIconVisible else { return }
        log("Reopened while icon hidden — revealing for this session.")
        menu.unhideIcon()
    }

    /// Same recovery path via the reopen Apple event (belt-and-suspenders:
    /// some launch paths deliver `reopen` without a become-active cycle).
    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        if let menu, !menu.isIconVisible {
            log("Reopen event while icon hidden — revealing for this session.")
            menu.unhideIcon()
        }
        return true
    }

    /// True when another process with this bundle identifier is already running.
    private func anotherInstanceIsRunning() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let myPID = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == bundleID && $0.processIdentifier != myPID
        }
    }

    @objc private func showMenuBarIcon() {
        menu?.unhideIcon()
    }

    private func log(_ message: String) {
        os_log("%{public}@", log: log, type: .info, message)
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
        DistributedNotificationCenter.default().removeObserver(self)
        keyTap.stop()
        updates.stop()
        permissionTimer?.invalidate()
    }
}
