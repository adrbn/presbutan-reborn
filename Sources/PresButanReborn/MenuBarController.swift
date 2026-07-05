import AppKit

final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let permissionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let loginItem = NSMenuItem()

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

        let checkUpdates = NSMenuItem(
            title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        checkUpdates.target = self
        menu.addItem(checkUpdates)

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

    @objc private func checkForUpdates() {
        UpdateChecker.checkInteractively()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
