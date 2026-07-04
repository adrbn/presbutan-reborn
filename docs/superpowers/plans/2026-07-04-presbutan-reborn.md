# PresButan Reborn Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu-bar background agent that restores Windows-style Finder keys — Return opens the selection, Delete trashes it, Shift+Delete deletes immediately — on macOS 13+ (incl. macOS 27).

**Architecture:** A SwiftPM executable, run as an `LSUIElement` accessory app. A `CGEventTap` intercepts key-down events; a pure `Remap` function maps candidate keys to synthetic shortcuts (⌘O / ⌘⌫ / ⌘⌥⌫); a `FinderContext` gate ensures we only act when Finder is frontmost and the user is *not* editing text (so renames still commit). Packaged into a `.app` bundle + DMG by a shell script, released via GitHub Actions.

**Tech Stack:** Swift 5.9+, SwiftPM, AppKit, ApplicationServices (Accessibility API), CoreGraphics (event taps), ServiceManagement (`SMAppService` login item). No third-party dependencies.

## Global Constraints

- **Minimum OS:** macOS 13.0 (Ventura) — required by `SMAppService`.
- **Bundle identifier:** `com.presbutanreborn.app`.
- **App display name:** `PresButan Reborn`. Executable/product name: `PresButanReborn`.
- **Scope:** Finder only (`com.apple.finder`). No third-party file managers. No per-behavior config UI.
- **Remap table (exact):** Return(36)/KeypadEnter(76) + no significant modifiers → ⌘O. Delete(51)/ForwardDelete(117) + no significant modifiers → ⌘⌫. Delete/ForwardDelete + Shift only → ⌘⌥⌫. Everything else → pass through.
- **Significant modifiers:** `.maskCommand`, `.maskShift`, `.maskControl`, `.maskAlternate`. Caps Lock, Fn, and numeric-pad flags are ignored.
- **Fail-safe:** if Accessibility focus state cannot be read, treat as "editing" and pass the key through — never hijack a possible rename.
- **Distribution:** unsigned-first. A signing/notarization hook is left commented in the build script for later. GPL-3.0 license.

---

### Task 1: Project scaffold + `Remap` core (TDD)

**Files:**
- Create: `Package.swift`
- Create: `Sources/PresButanReborn/Remap.swift`
- Test: `Tests/PresButanRebornTests/RemapTests.swift`

**Interfaces:**
- Produces:
  - `enum KeyCode` — static `CGKeyCode` constants: `returnKey=36`, `keypadEnter=76`, `delete=51`, `forwardDelete=117`, `letterO=31`.
  - `struct SyntheticKey: Equatable { let keyCode: CGKeyCode; let flags: CGEventFlags }`.
  - `enum RemapAction: Equatable { case passThrough; case send([SyntheticKey]) }`.
  - `enum Remap { static func action(forKeyCode: CGKeyCode, flags: CGEventFlags) -> RemapAction }`.

- [ ] **Step 1: Create the SwiftPM manifest**

Create `Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PresButanReborn",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PresButanReborn",
            path: "Sources/PresButanReborn"
        ),
        .testTarget(
            name: "PresButanRebornTests",
            dependencies: ["PresButanReborn"],
            path: "Tests/PresButanRebornTests"
        ),
    ]
)
```

- [ ] **Step 2: Write the failing test**

Create `Tests/PresButanRebornTests/RemapTests.swift`:

```swift
import XCTest
import CoreGraphics
@testable import PresButanReborn

final class RemapTests: XCTestCase {
    private let cmd: CGEventFlags = .maskCommand
    private let cmdOpt: CGEventFlags = [.maskCommand, .maskAlternate]

    func testReturnMapsToCommandO() {
        XCTAssertEqual(
            Remap.action(forKeyCode: KeyCode.returnKey, flags: []),
            .send([SyntheticKey(keyCode: KeyCode.letterO, flags: cmd)])
        )
    }

    func testKeypadEnterMapsToCommandO() {
        // Keypad Enter often carries the numeric-pad flag; it must be ignored.
        XCTAssertEqual(
            Remap.action(forKeyCode: KeyCode.keypadEnter, flags: .maskNumericPad),
            .send([SyntheticKey(keyCode: KeyCode.letterO, flags: cmd)])
        )
    }

    func testDeleteMapsToCommandDelete() {
        XCTAssertEqual(
            Remap.action(forKeyCode: KeyCode.delete, flags: []),
            .send([SyntheticKey(keyCode: KeyCode.delete, flags: cmd)])
        )
    }

    func testForwardDeleteMapsToCommandDelete() {
        XCTAssertEqual(
            Remap.action(forKeyCode: KeyCode.forwardDelete, flags: []),
            .send([SyntheticKey(keyCode: KeyCode.delete, flags: cmd)])
        )
    }

    func testShiftDeleteMapsToDeleteImmediately() {
        XCTAssertEqual(
            Remap.action(forKeyCode: KeyCode.delete, flags: .maskShift),
            .send([SyntheticKey(keyCode: KeyCode.delete, flags: cmdOpt)])
        )
    }

    func testCapsLockIsIgnoredOnReturn() {
        XCTAssertEqual(
            Remap.action(forKeyCode: KeyCode.returnKey, flags: .maskAlphaShift),
            .send([SyntheticKey(keyCode: KeyCode.letterO, flags: cmd)])
        )
    }

    func testCommandReturnPassesThrough() {
        XCTAssertEqual(Remap.action(forKeyCode: KeyCode.returnKey, flags: .maskCommand), .passThrough)
    }

    func testOptionDeletePassesThrough() {
        XCTAssertEqual(Remap.action(forKeyCode: KeyCode.delete, flags: .maskAlternate), .passThrough)
    }

    func testLetterKeyPassesThrough() {
        // 'A' == keyCode 0
        XCTAssertEqual(Remap.action(forKeyCode: 0, flags: []), .passThrough)
    }
}
```

- [ ] **Step 3: Run the test — verify it fails to build**

Run: `swift test`
Expected: FAIL — `cannot find 'Remap' in scope` (and `KeyCode`, `SyntheticKey`).

- [ ] **Step 4: Implement `Remap.swift`**

Create `Sources/PresButanReborn/Remap.swift`:

```swift
import CoreGraphics

enum KeyCode {
    static let returnKey: CGKeyCode = 36
    static let keypadEnter: CGKeyCode = 76
    static let delete: CGKeyCode = 51
    static let forwardDelete: CGKeyCode = 117
    static let letterO: CGKeyCode = 31
}

struct SyntheticKey: Equatable {
    let keyCode: CGKeyCode
    let flags: CGEventFlags

    static func == (lhs: SyntheticKey, rhs: SyntheticKey) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.flags.rawValue == rhs.flags.rawValue
    }
}

enum RemapAction: Equatable {
    case passThrough
    case send([SyntheticKey])
}

enum Remap {
    private static let significant: CGEventFlags =
        [.maskCommand, .maskShift, .maskControl, .maskAlternate]

    static func action(forKeyCode keyCode: CGKeyCode, flags: CGEventFlags) -> RemapAction {
        let mods = flags.intersection(significant)

        switch keyCode {
        case KeyCode.returnKey, KeyCode.keypadEnter:
            guard mods.isEmpty else { return .passThrough }
            return .send([SyntheticKey(keyCode: KeyCode.letterO, flags: .maskCommand)])

        case KeyCode.delete, KeyCode.forwardDelete:
            if mods.isEmpty {
                return .send([SyntheticKey(keyCode: KeyCode.delete, flags: .maskCommand)])
            } else if mods == .maskShift {
                return .send([SyntheticKey(keyCode: KeyCode.delete,
                                           flags: [.maskCommand, .maskAlternate])])
            } else {
                return .passThrough
            }

        default:
            return .passThrough
        }
    }
}
```

- [ ] **Step 5: Run the test — verify it passes**

Run: `swift test`
Expected: PASS (9 tests).

- [ ] **Step 6: Commit**

```bash
printf '.build/\nbuild/\n.DS_Store\n*.xcodeproj\n' > .gitignore
git add .gitignore Package.swift Sources/PresButanReborn/Remap.swift Tests/PresButanRebornTests/RemapTests.swift
git commit -m "feat: add pure Remap key-mapping core with tests"
```

---

### Task 2: `FinderContext` — frontmost + rename detection

**Files:**
- Create: `Sources/PresButanReborn/FinderContext.swift`
- Test: `Tests/PresButanRebornTests/FinderContextTests.swift`

**Interfaces:**
- Produces:
  - `protocol FinderContextProviding { func isFinderFrontmost() -> Bool; func isEditingText() -> Bool }`
  - `final class FinderContext: FinderContextProviding` — real implementation.
- Consumed by: `KeyTap` (Task 3).

- [ ] **Step 1: Write the failing test**

The real AX/NSWorkspace behavior needs a live Finder, so the unit test verifies the protocol seam via a stub (used later by KeyTap) plus a non-crashing smoke call on the real type.

Create `Tests/PresButanRebornTests/FinderContextTests.swift`:

```swift
import XCTest
@testable import PresButanReborn

final class StubFinderContext: FinderContextProviding {
    var frontmost = true
    var editing = false
    func isFinderFrontmost() -> Bool { frontmost }
    func isEditingText() -> Bool { editing }
}

final class FinderContextTests: XCTestCase {
    func testStubReportsInjectedState() {
        let stub = StubFinderContext()
        stub.frontmost = false
        stub.editing = true
        XCTAssertFalse(stub.isFinderFrontmost())
        XCTAssertTrue(stub.isEditingText())
    }

    func testRealContextDoesNotCrash() {
        // In headless CI there is no frontmost Finder; must simply return without crashing.
        let ctx = FinderContext()
        _ = ctx.isFinderFrontmost()
        _ = ctx.isEditingText()
    }
}
```

- [ ] **Step 2: Run the test — verify it fails to build**

Run: `swift test`
Expected: FAIL — `cannot find 'FinderContextProviding' / 'FinderContext' in scope`.

- [ ] **Step 3: Implement `FinderContext.swift`**

Create `Sources/PresButanReborn/FinderContext.swift`:

```swift
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
```

- [ ] **Step 4: Run the test — verify it passes**

Run: `swift test`
Expected: PASS (all Task 1 + Task 2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/PresButanReborn/FinderContext.swift Tests/PresButanRebornTests/FinderContextTests.swift
git commit -m "feat: add FinderContext frontmost + rename detection with stub seam"
```

---

### Task 3: `KeyTap` + `EventPoster` — the event-tap engine

**Files:**
- Create: `Sources/PresButanReborn/EventPoster.swift`
- Create: `Sources/PresButanReborn/KeyTap.swift`
- Test: `Tests/PresButanRebornTests/KeyTapTests.swift`

**Interfaces:**
- Consumes: `Remap.action(forKeyCode:flags:)`, `FinderContextProviding`.
- Produces:
  - `protocol EventPosting { func post(_ keys: [SyntheticKey]) }`
  - `final class EventPoster: EventPosting`
  - `final class KeyTap { init(context: FinderContextProviding, poster: EventPosting); @discardableResult func start() -> Bool; func stop(); static let sentinel: Int64 }`
  - `func decide(type:isSynthetic:isRepeat:keyCode:flags:) -> TapDecision` — pure helper split out for testing.
  - `enum TapDecision: Equatable { case passThrough; case swallow; case remap([SyntheticKey]) }`

- [ ] **Step 1: Write the failing test for the pure decision helper**

The tap callback itself needs the real HID system, but its branching logic is extracted into a pure `KeyTap.decide(...)` we can unit-test exhaustively.

Create `Tests/PresButanRebornTests/KeyTapTests.swift`:

```swift
import XCTest
import CoreGraphics
@testable import PresButanReborn

final class KeyTapTests: XCTestCase {
    func testSyntheticEventsArePassedThrough() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: true, isRepeat: false,
                              keyCode: KeyCode.returnKey, flags: [],
                              finderFrontmost: true, editing: false)
        XCTAssertEqual(d, .passThrough)
    }

    func testNonFinderCandidatePassesThrough() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: false, isRepeat: false,
                              keyCode: KeyCode.delete, flags: [],
                              finderFrontmost: false, editing: false)
        XCTAssertEqual(d, .passThrough)
    }

    func testEditingCandidatePassesThrough() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: false, isRepeat: false,
                              keyCode: KeyCode.returnKey, flags: [],
                              finderFrontmost: true, editing: true)
        XCTAssertEqual(d, .passThrough)
    }

    func testFinderReturnRemaps() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: false, isRepeat: false,
                              keyCode: KeyCode.returnKey, flags: [],
                              finderFrontmost: true, editing: false)
        XCTAssertEqual(d, .remap([SyntheticKey(keyCode: KeyCode.letterO, flags: .maskCommand)]))
    }

    func testRepeatOfCandidateInFinderIsSwallowed() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: false, isRepeat: true,
                              keyCode: KeyCode.delete, flags: [],
                              finderFrontmost: true, editing: false)
        XCTAssertEqual(d, .swallow)
    }

    func testNonCandidateInFinderPassesThrough() {
        let d = KeyTap.decide(type: .keyDown, isSynthetic: false, isRepeat: false,
                              keyCode: 0, flags: [],
                              finderFrontmost: true, editing: false)
        XCTAssertEqual(d, .passThrough)
    }
}
```

- [ ] **Step 2: Run the test — verify it fails to build**

Run: `swift test`
Expected: FAIL — `cannot find 'KeyTap' in scope`.

- [ ] **Step 3: Implement `EventPoster.swift`**

Create `Sources/PresButanReborn/EventPoster.swift`:

```swift
import CoreGraphics

protocol EventPosting {
    func post(_ keys: [SyntheticKey])
}

final class EventPoster: EventPosting {
    private let source = CGEventSource(stateID: .combinedSessionState)

    func post(_ keys: [SyntheticKey]) {
        for key in keys {
            emit(key, keyDown: true)
            emit(key, keyDown: false)
        }
    }

    private func emit(_ key: SyntheticKey, keyDown: Bool) {
        guard let event = CGEvent(keyboardEventSource: source,
                                  virtualKey: key.keyCode,
                                  keyDown: keyDown) else { return }
        event.flags = key.flags
        event.setIntegerValueField(.eventSourceUserData, value: KeyTap.sentinel)
        event.post(tap: .cgSessionEventTap)
    }
}
```

- [ ] **Step 4: Implement `KeyTap.swift`**

Create `Sources/PresButanReborn/KeyTap.swift`:

```swift
import CoreGraphics
import CoreFoundation

enum TapDecision: Equatable {
    case passThrough
    case swallow
    case remap([SyntheticKey])
}

final class KeyTap {
    /// Sentinel written into `.eventSourceUserData` on our own synthetic events
    /// so the tap never re-processes what it just posted. "PBR\0".
    static let sentinel: Int64 = 0x5042_5200

    private let context: FinderContextProviding
    private let poster: EventPosting
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(context: FinderContextProviding, poster: EventPosting) {
        self.context = context
        self.poster = poster
    }

    /// Pure decision logic, unit-tested in isolation.
    static func decide(type: CGEventType,
                       isSynthetic: Bool,
                       isRepeat: Bool,
                       keyCode: CGKeyCode,
                       flags: CGEventFlags,
                       finderFrontmost: Bool,
                       editing: Bool) -> TapDecision {
        guard type == .keyDown else { return .passThrough }
        if isSynthetic { return .passThrough }

        guard case let .send(keys) = Remap.action(forKeyCode: keyCode, flags: flags) else {
            return .passThrough
        }
        // Only after confirming this is a remap candidate do we consult Finder state,
        // so normal typing never triggers an Accessibility read.
        guard finderFrontmost, !editing else { return .passThrough }
        if isRepeat { return .swallow }
        return .remap(keys)
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: KeyTap.cCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        return true
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private static let cCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let tap = Unmanaged<KeyTap>.fromOpaque(refcon).takeUnretainedValue()
        return tap.handle(type: type, event: event)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let isSynthetic = event.getIntegerValueField(.eventSourceUserData) == KeyTap.sentinel
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        // Cheap pre-check so we only pay for Accessibility reads on candidate keys.
        let isCandidate: Bool
        if case .send = Remap.action(forKeyCode: keyCode, flags: event.flags) {
            isCandidate = true
        } else {
            isCandidate = false
        }
        let frontmost = (isCandidate && !isSynthetic) ? context.isFinderFrontmost() : false
        let editing = frontmost ? context.isEditingText() : false

        switch KeyTap.decide(type: type, isSynthetic: isSynthetic, isRepeat: isRepeat,
                             keyCode: keyCode, flags: event.flags,
                             finderFrontmost: frontmost, editing: editing) {
        case .passThrough:
            return Unmanaged.passUnretained(event)
        case .swallow:
            return nil
        case .remap(let keys):
            poster.post(keys)
            return nil
        }
    }
}
```

- [ ] **Step 5: Run the test — verify it passes**

Run: `swift test`
Expected: PASS (Task 1 + 2 + 3 tests).

- [ ] **Step 6: Commit**

```bash
git add Sources/PresButanReborn/EventPoster.swift Sources/PresButanReborn/KeyTap.swift Tests/PresButanRebornTests/KeyTapTests.swift
git commit -m "feat: add CGEventTap engine with testable decision logic"
```

---

### Task 4: `Permissions` — Accessibility trust + settings deep-link

**Files:**
- Create: `Sources/PresButanReborn/Permissions.swift`
- Test: `Tests/PresButanRebornTests/PermissionsTests.swift`

**Interfaces:**
- Produces: `enum Permissions` with `static func isTrusted() -> Bool`, `static func promptIfNeeded() -> Bool`, `static let accessibilitySettingsURL: URL`, `static func openAccessibilitySettings()`.

- [ ] **Step 1: Write the failing test**

Create `Tests/PresButanRebornTests/PermissionsTests.swift`:

```swift
import XCTest
@testable import PresButanReborn

final class PermissionsTests: XCTestCase {
    func testAccessibilitySettingsURLIsCorrect() {
        XCTAssertEqual(
            Permissions.accessibilitySettingsURL.absoluteString,
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )
    }

    func testIsTrustedReturnsBoolWithoutCrashing() {
        _ = Permissions.isTrusted()
    }
}
```

- [ ] **Step 2: Run the test — verify it fails to build**

Run: `swift test`
Expected: FAIL — `cannot find 'Permissions' in scope`.

- [ ] **Step 3: Implement `Permissions.swift`**

Create `Sources/PresButanReborn/Permissions.swift`:

```swift
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
        let options = [kAXTrustedCheckOptionPrompt as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        NSWorkspace.shared.open(accessibilitySettingsURL)
    }
}
```

- [ ] **Step 4: Run the test — verify it passes**

Run: `swift test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/PresButanReborn/Permissions.swift Tests/PresButanRebornTests/PermissionsTests.swift
git commit -m "feat: add Accessibility permission helper"
```

---

### Task 5: `LoginItem` — launch at login

**Files:**
- Create: `Sources/PresButanReborn/LoginItem.swift`
- Test: `Tests/PresButanRebornTests/LoginItemTests.swift`

**Interfaces:**
- Produces: `enum LoginItem` with `static var isEnabled: Bool`, `static func setEnabled(_ enabled: Bool) throws`.

- [ ] **Step 1: Write the failing test**

`SMAppService` only registers from a real bundle, so the unit test only asserts the status read is non-crashing and returns a `Bool`.

Create `Tests/PresButanRebornTests/LoginItemTests.swift`:

```swift
import XCTest
@testable import PresButanReborn

final class LoginItemTests: XCTestCase {
    func testIsEnabledReturnsBoolWithoutCrashing() {
        let value: Bool = LoginItem.isEnabled
        XCTAssertTrue(value == true || value == false)
    }
}
```

- [ ] **Step 2: Run the test — verify it fails to build**

Run: `swift test`
Expected: FAIL — `cannot find 'LoginItem' in scope`.

- [ ] **Step 3: Implement `LoginItem.swift`**

Create `Sources/PresButanReborn/LoginItem.swift`:

```swift
import ServiceManagement

/// Wraps SMAppService (macOS 13+). Note: reliable registration requires a
/// signed, installed .app; unsigned dev builds may report `.notRegistered`
/// or throw — the caller surfaces the error.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
```

- [ ] **Step 4: Run the test — verify it passes**

Run: `swift test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/PresButanReborn/LoginItem.swift Tests/PresButanRebornTests/LoginItemTests.swift
git commit -m "feat: add SMAppService login-item wrapper"
```

---

### Task 6: `MenuBarController` — status item + menu

**Files:**
- Create: `Sources/PresButanReborn/MenuBarController.swift`

**Interfaces:**
- Consumes: `Permissions`, `LoginItem`.
- Produces: `final class MenuBarController: NSObject { init(); func refresh() }` — owns an `NSStatusItem`.

This task is AppKit UI wiring; it is verified by build + manual inspection (Task 8), not a unit test.

- [ ] **Step 1: Implement `MenuBarController.swift`**

Create `Sources/PresButanReborn/MenuBarController.swift`:

```swift
import AppKit

final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let permissionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let loginItem = NSMenuItem(
        title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")

    override init() {
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "return", accessibilityDescription: "PresButan Reborn")
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

        loginItem.target = self
        menu.addItem(loginItem)

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

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
```

- [ ] **Step 2: Verify it builds**

Run: `swift build`
Expected: Builds with no errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/PresButanReborn/MenuBarController.swift
git commit -m "feat: add menu-bar status item and menu"
```

---

### Task 7: App entry point + wiring

**Files:**
- Create: `Sources/PresButanReborn/AppDelegate.swift`
- Replace: `Sources/PresButanReborn/main.swift` (a placeholder was added early during Task 2 to satisfy the linker — overwrite its contents with the real bootstrap below)

**Interfaces:**
- Consumes: `FinderContext`, `EventPoster`, `KeyTap`, `Permissions`, `MenuBarController`.
- Produces: a runnable accessory app. On launch it prompts for Accessibility, starts the tap, and retries once granted.

Verified by `swift run` (launches, menu appears) plus Task 8 manual QA.

- [ ] **Step 1: Implement `AppDelegate.swift`**

Create `Sources/PresButanReborn/AppDelegate.swift`:

```swift
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
```

- [ ] **Step 2: Implement `main.swift`**

Replace the placeholder `Sources/PresButanReborn/main.swift` (added during Task 2) with:

```swift
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // no Dock icon; menu-bar only
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

- [ ] **Step 3: Verify it builds and the tests still pass**

Run: `swift build && swift test`
Expected: Builds; all tests PASS.

- [ ] **Step 4: Smoke-run (optional, local only)**

Run: `swift run`
Expected: a menu-bar icon appears; macOS shows the Accessibility prompt. `Ctrl+C` to stop. (Full remap behavior requires the bundled app from Task 8 with Accessibility granted.)

- [ ] **Step 5: Commit**

```bash
git add Sources/PresButanReborn/AppDelegate.swift Sources/PresButanReborn/main.swift
git commit -m "feat: wire app entry point, permission retry, and tap lifecycle"
```

---

### Task 8: `.app` bundle + DMG packaging + manual QA

**Files:**
- Create: `Resources/Info.plist`
- Create: `scripts/build-dmg.sh`

**Interfaces:**
- Consumes: the built `PresButanReborn` executable.
- Produces: `build/PresButan Reborn.app` and `build/PresButanReborn.dmg`.

- [ ] **Step 1: Create `Resources/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>PresButan Reborn</string>
    <key>CFBundleDisplayName</key>
    <string>PresButan Reborn</string>
    <key>CFBundleIdentifier</key>
    <string>com.presbutanreborn.app</string>
    <key>CFBundleExecutable</key>
    <string>PresButanReborn</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHumanReadableCopyright</key>
    <string>GPL-3.0 License. PresButan Reborn contributors.</string>
</dict>
</plist>
```

- [ ] **Step 2: Create `scripts/build-dmg.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PresButan Reborn"
EXECUTABLE="PresButanReborn"
CONFIG="release"
OUT="build"

echo "==> Building ($CONFIG)…"
swift build -c "$CONFIG"

BIN=".build/${CONFIG}/${EXECUTABLE}"
APP_DIR="${OUT}/${APP_NAME}.app"

echo "==> Assembling ${APP_DIR}…"
rm -rf "$APP_DIR"
mkdir -p "${APP_DIR}/Contents/MacOS"
cp "$BIN" "${APP_DIR}/Contents/MacOS/${EXECUTABLE}"
cp "Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"

# --- Signing / notarization hook (unsigned-first; enable when an account exists) ---
# codesign --force --options runtime --sign "Developer ID Application: NAME (TEAMID)" "$APP_DIR"
# xcrun notarytool submit "$DMG" --keychain-profile "AC_PROFILE" --wait
# xcrun stapler staple "$DMG"
# ----------------------------------------------------------------------------------

DMG="${OUT}/${EXECUTABLE}.dmg"
echo "==> Creating ${DMG}…"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_DIR" -ov -format UDZO "$DMG"

echo "==> Done: $DMG"
```

- [ ] **Step 3: Build the bundle and DMG**

Run:
```bash
chmod +x scripts/build-dmg.sh
./scripts/build-dmg.sh
```
Expected: `build/PresButan Reborn.app` and `build/PresButanReborn.dmg` exist; final line `==> Done: build/PresButanReborn.dmg`.

- [ ] **Step 4: Manual QA (run the bundled app)**

```bash
open "build/PresButan Reborn.app"
```
Grant Accessibility when prompted (System Settings → Privacy & Security → Accessibility → enable *PresButan Reborn*), then verify each row:

1. Rename a file (single-click name or Return-to-rename via macOS setting), edit, press **Return** → rename **commits** (not opened).
2. Select a file, press **Return** → file **opens**.
3. Select a folder, press **Return** → folder **opens/navigates in**.
4. Select an item, press **Delete** → **moves to Trash**.
5. **Shift+Delete** → Finder's native "Delete Immediately?" confirm appears; confirming deletes.
6. Click Finder's **search field**, type text, press **Return/Enter** → normal search (not hijacked).
7. Switch to **TextEdit**, press **Return/Delete** → behave normally (untouched).
8. Menu-bar icon shows **Accessibility: Granted**; **Quit** exits.

Record any failures before committing.

- [ ] **Step 5: Commit**

```bash
git add Resources/Info.plist scripts/build-dmg.sh
git commit -m "build: add app bundle Info.plist and DMG packaging script"
```

---

### Task 9: CI + release workflows

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Create `.github/workflows/ci.yml`**

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build-test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Swift version
        run: swift --version
      - name: Build
        run: swift build
      - name: Test
        run: swift test
```

- [ ] **Step 2: Create `.github/workflows/release.yml`**

```yaml
name: Release

on:
  push:
    tags: ["v*"]

permissions:
  contents: write

jobs:
  release:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build DMG
        run: |
          chmod +x scripts/build-dmg.sh
          ./scripts/build-dmg.sh
      - name: Attach DMG to release
        uses: softprops/action-gh-release@v2
        with:
          files: build/PresButanReborn.dmg
```

- [ ] **Step 3: Validate the CI steps locally**

Run: `swift build && swift test`
Expected: both succeed (mirrors what CI runs).

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml .github/workflows/release.yml
git commit -m "ci: add build/test workflow and tagged DMG release workflow"
```

---

### Task 10: README + LICENSE

**Files:**
- Create: `README.md`
- Create: `LICENSE`

- [ ] **Step 1: Create `LICENSE` (GPL-3.0)**

```text
GNU GENERAL PUBLIC LICENSE, Version 3, 29 June 2007

(full text: https://www.gnu.org/licenses/gpl-3.0.txt)
```

- [ ] **Step 2: Create `README.md`**

```markdown
# PresButan Reborn

Make macOS Finder behave like Windows Explorer:

- **Return / Enter** → opens the selected item (instead of renaming it)
- **Delete / Backspace** → moves the selection to Trash
- **Shift + Delete** → deletes immediately (with Finder's native confirmation)

A tiny, open-source successor to the original PresButan (last updated 2012),
rebuilt natively for modern macOS (13 Ventura and later, including macOS 27).

## Why

The original PresButan is abandonware. A 64-bit build kept working for years but
broke on the move to macOS 27. PresButan Reborn is a maintained, from-scratch
replacement using current macOS APIs (a keyboard event tap gated by the
Accessibility API), so renames still commit correctly and only Finder is affected.

## Install

1. Download `PresButanReborn.dmg` from the [Releases](../../releases) page.
2. Open the DMG and drag **PresButan Reborn** to `/Applications`.
3. Because builds are currently **unsigned**, macOS Gatekeeper will warn on first
   launch. Right-click the app → **Open** → **Open**. (Or run:
   `xattr -dr com.apple.quarantine "/Applications/PresButan Reborn.app"`.)
4. On first launch, grant Accessibility:
   **System Settings → Privacy & Security → Accessibility → enable PresButan Reborn**.
5. Use the menu-bar icon to toggle **Launch at Login**.

## How it works

A background agent (`LSUIElement`, no Dock icon) installs a `CGEventTap`. When
Finder is frontmost and you are *not* editing text, it remaps Return→⌘O,
Delete→⌘⌫, and Shift+Delete→⌘⌥⌫. All other keys and apps are untouched.

## Build from source

```bash
swift build
swift test
./scripts/build-dmg.sh   # produces build/PresButanReborn.dmg
```

## License

GPL-3.0 — see [LICENSE](LICENSE).
```

- [ ] **Step 3: Commit**

```bash
git add README.md LICENSE
git commit -m "docs: add README and license"
```

---

## Post-implementation notes

- **Known limitation (unsigned builds):** `SMAppService` launch-at-login registration is most reliable from a signed app installed in `/Applications`. On unsigned dev builds the toggle may throw; the menu surfaces the error. Revisit when Developer ID signing is enabled (hook in `scripts/build-dmg.sh`).
- **Screenshots:** add menu-bar and permission-grant screenshots to the README before the Reddit (r/macapps) post.
- **Follow-ups (out of scope for v1):** custom template menu-bar icon; optional per-behavior toggles if users request them; Sparkle auto-update.
