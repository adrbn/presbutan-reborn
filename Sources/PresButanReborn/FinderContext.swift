import AppKit
import ApplicationServices

protocol FinderContextProviding {
    func isFinderFrontmost() -> Bool
    func isEditingText() -> Bool
    func overlayPanelHasKeyboardFocus() -> Bool
}

final class FinderContext: FinderContextProviding {
    private let finderBundleID = "com.apple.finder"

    /// The event tap is synchronous — every millisecond spent here delays the
    /// keystroke. Cap AX messaging well under the tap's own timeout so a wedged
    /// process can never stall typing.
    private static let axTimeout: Float = 0.05

    private let systemWide: AXUIElement = {
        let element = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(element, axTimeout)
        return element
    }()

    func isFinderFrontmost() -> Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == finderBundleID
    }

    /// True when the Finder focus is a text field (mid-rename, search field, etc.).
    /// Fails safe: if focus state can't be read, returns true so we never hijack a rename.
    func isEditingText() -> Bool {
        guard let finder = NSWorkspace.shared.frontmostApplication,
              finder.bundleIdentifier == finderBundleID else {
            return false
        }

        let appElement = AXUIElementCreateApplication(finder.processIdentifier)

        var focused: AnyObject?
        let focusErr = AXUIElementCopyAttributeValue(
            appElement, kAXFocusedUIElementAttribute as CFString, &focused)
        guard focusErr == .success, let focusedElement = focused else {
            return true
        }

        // focusedElement is an AXUIElement (CFType).
        guard CFGetTypeID(focusedElement) == AXUIElementGetTypeID() else { return true }
        let element = focusedElement as! AXUIElement
        var roleValue: AnyObject?
        let roleErr = AXUIElementCopyAttributeValue(
            element, kAXRoleAttribute as CFString, &roleValue)
        guard roleErr == .success, let role = roleValue as? String else {
            return true
        }

        return role == (kAXTextFieldRole as String) || role == (kAXTextAreaRole as String)
    }

    /// True when a process *other* than the frontmost application owns the keyboard.
    ///
    /// Spotlight — and every launcher built like it (Raycast, Alfred, LaunchBar) —
    /// shows a non-activating panel: it takes keyboard focus without ever becoming
    /// the frontmost application. `NSWorkspace.frontmostApplication` therefore still
    /// reports Finder, and without this check a bare Return typed into Spotlight was
    /// swallowed and replaced with Cmd-O, which the panel ignores.
    ///
    /// The system-wide focused element does follow the panel, so comparing its owner
    /// against the frontmost application detects any such overlay generically, with
    /// no hardcoded bundle identifiers.
    ///
    /// Deliberately conservative: this returns true only when another owner is
    /// positively identified. If the Accessibility read fails for any reason the
    /// answer is false, leaving the frontmost-application check in charge — a flaky
    /// AX read must never silently turn the remap off.
    func overlayPanelHasKeyboardFocus() -> Bool {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return false }

        var focused: AnyObject?
        let focusErr = AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focused)
        guard focusErr == .success, let focusedElement = focused,
              CFGetTypeID(focusedElement) == AXUIElementGetTypeID() else {
            return false
        }

        var owner: pid_t = 0
        guard AXUIElementGetPid(focusedElement as! AXUIElement, &owner) == .success else {
            return false
        }

        return owner != frontmost.processIdentifier
    }
}
