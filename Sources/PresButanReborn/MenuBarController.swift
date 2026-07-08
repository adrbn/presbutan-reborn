import AppKit

final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let permissionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let loginItem = NSMenuItem()
    private let hideIconItem = NSMenuItem()

    /// Distributed notification posted by a second launch (e.g. the user runs
    /// `open -n` or opens the .app while another instance is starting) to ask
    /// the already-running instance to reveal its menu-bar icon.
    static let showIconNotification = Notification.Name("com.presbutanreborn.ShowMenuBar")

    private static let hideIconKey = "HideMenuBarIcon"

    /// Persisted preference: whether the icon should be hidden on next launch.
    static var prefHideIcon: Bool {
        UserDefaults.standard.bool(forKey: hideIconKey)
    }

    /// Whether the status item is currently on screen.
    var isIconVisible: Bool {
        statusItem.isVisible
    }

    override init() {
        super.init()
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "return", accessibilityDescription: "PresButan Reborn") {
                button.image = image
            } else {
                button.title = "PB"
            }
        }
        buildMenu()
        refresh()
        applyIconVisibility()
    }

    private func buildMenu() {
        let menu = NSMenu()

        permissionItem.isEnabled = false
        menu.addItem(permissionItem)

        let openSettings = NSMenuItem(
            title: "Open Accessibility Settings…",
            action: #selector(openAccessibilitySettings), keyEquivalent: "")
        openSettings.target = self
        menu.addItem(openSettings)

        menu.addItem(.separator())

        loginItem.title = "Launch at Login"
        loginItem.action = #selector(toggleLaunchAtLogin)
        loginItem.target = self
        menu.addItem(loginItem)

        hideIconItem.title = "Hide Menu Bar Icon"
        hideIconItem.action = #selector(toggleHideIcon)
        hideIconItem.target = self
        menu.addItem(hideIconItem)

        let checkUpdates = NSMenuItem(
            title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        checkUpdates.target = self
        menu.addItem(checkUpdates)

        menu.addItem(.separator())

        let github = NSMenuItem(
            title: "View on GitHub", action: #selector(openGitHub), keyEquivalent: "")
        github.target = self
        github.image = BrandIcons.github()
        menu.addItem(github)

        let kofi = NSMenuItem(
            title: "Donate on Ko-fi", action: #selector(openKofi), keyEquivalent: "")
        kofi.target = self
        if let cup = NSImage(systemSymbolName: "cup.and.saucer.fill",
                             accessibilityDescription: "Ko-fi") {
            kofi.image = cup
        }
        menu.addItem(kofi)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit PresButan Reborn", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    func refresh() {
        permissionItem.title = Permissions.isTrusted()
            ? "Accessibility: Granted"
            : "Accessibility: Needs Permission"
        loginItem.state = LoginItem.isEnabled ? .on : .off
        // The menu item reflects the CURRENT runtime visibility, not the pref:
        // a hidden icon that was temporarily revealed by reopening the app
        // should show as unchecked so the user can re-hide it from the menu.
        hideIconItem.state = isIconVisible ? .off : .on
    }

    /// Hides or shows the status item to match the persisted preference.
    /// Called once at launch; thereafter visibility is controlled by the user
    /// (menu toggle) or by reopening the app (session-only reveal).
    private func applyIconVisibility() {
        statusItem.isVisible = !Self.prefHideIcon
    }

    /// Reveals the icon for the current session without touching the persisted
    /// preference — so a hidden-on-launch app stays hidden across reboots, but
    /// the user can still bring the icon back by reopening the .app.
    func unhideIcon() {
        statusItem.isVisible = true
        refresh()
    }

    @objc private func openAccessibilitySettings() {
        Permissions.openAccessibilitySettings()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try LoginItem.setEnabled(!LoginItem.isEnabled)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        refresh()
    }

    @objc private func toggleHideIcon() {
        // Toggling from the menu writes the pref, so the choice persists
        // across launches (unlike the session-only reveal from reopening).
        let nowHidden = isIconVisible   // if currently visible, we're about to hide
        if nowHidden {
            // Confirm — once hidden, the menu is unreachable until the app is
            // opened again from /Applications (or Spotlight).
            let alert = NSAlert()
            alert.messageText = "Hide menu bar icon?"
            alert.informativeText = """
                The icon will disappear but PresButan Reborn keeps running. \
                To show it again, open PresButan Reborn from /Applications or Spotlight.
                """
            alert.addButton(withTitle: "Hide")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertSecondButtonReturn {
                refresh()
                return
            }
        }
        UserDefaults.standard.set(nowHidden, forKey: Self.hideIconKey)
        statusItem.isVisible = !nowHidden
        refresh()
    }

    @objc private func checkForUpdates() {
        UpdateChecker.checkInteractively()
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(UpdateChecker.repositoryURL)
    }

    @objc private func openKofi() {
        if let url = URL(string: "https://ko-fi.com/adrbn") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
