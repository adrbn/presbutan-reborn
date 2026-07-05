import AppKit
import ApplicationServices

protocol FinderContextProviding {
    func isFinderFrontmost() -> Bool
    func isEditingText() -> Bool
}

final class FinderContext: FinderContextProviding {
    private let finderBundleID = "com.apple.finder"

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
}
