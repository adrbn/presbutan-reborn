import AppKit
import ApplicationServices

enum Permissions {
    static let accessibilitySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )!

    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Triggers the system Accessibility prompt if not yet granted.
    @discardableResult
    static func promptIfNeeded() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        NSWorkspace.shared.open(accessibilitySettingsURL)
    }
}
