# PresButan Reborn — Design

**Date:** 2026-07-04
**Status:** Approved (pending spec review)

## 1. Problem

The original [PresButan](https://presbutan.macupdate.com/) (v1.4, last updated **Feb 3, 2012**) is a tiny Finder tweak that made Windows-switchers feel at home:

- **Return/Enter** opens the selected file instead of renaming it.
- **Delete/Backspace** moves the selection to Trash instead of doing nothing.

The public **MacUpdate listing** shows an ancient v1.4 (32-bit Intel/PPC, 2012). But that is *not* the build people actually run — a 32-bit binary cannot launch after macOS 10.15 Catalina removed 32-bit support, yet a later **64-bit** recompile has kept working for years. It ran fine on **macOS 26.5** and only stopped **a few days ago**, coinciding with an upgrade to **macOS 27** (this machine now reports Darwin 27).

So the accurate picture is *not* "dead since 2019" — it is **freshly broken on macOS 27**, with no maintainer to fix it (last official release: 2012). Whether macOS 27 changed the event-tap / Finder-Accessibility path, or merely reset the app's Accessibility permission on upgrade, the conclusion is the same: an abandoned 2012-era app that no one will patch. (A permission re-grant is worth trying as a stopgap, but does not change the case for a maintained successor.)

**Goal:** Build a clean, modern successor that restores this behavior on current and future macOS, distributed as an open-source app.

## 2. Scope

### In scope (approved behaviors)

| Trigger | Modifiers | Action sent | Effect |
|---|---|---|---|
| Return / Keypad Enter | none | ⌘O | Open selection |
| Delete / Forward Delete | none | ⌘⌫ | Move selection to Trash |
| Delete / Forward Delete | Shift | ⌘⌥⌫ | Delete Immediately (Finder shows its own native confirmation dialog) |

- Fires **only** when Finder is the frontmost app **and** the user is **not** editing text (mid-rename, search field, etc.).
- Any other key, or any of these keys with an unexpected modifier (⌘/⌥/⌃), passes through untouched.

### Out of scope (YAGNI)

- No per-behavior on/off toggles in the UI (user explicitly declined a config panel).
- No support for third-party file managers — Finder only.
- No custom confirmation dialogs — we reuse Finder's native "Delete Immediately" confirm for free.
- No preferences window, no updater framework (initial release).

## 3. Architecture

A single `LSUIElement` background agent (menu-bar icon, no Dock icon). **Minimum target: macOS 13 Ventura** (required by `SMAppService` for launch-at-login).

### Data flow

```
keyDown event
   │
   ▼
KeyTap callback ──(our own synthetic event? tag match)──► pass through
   │ no
   ▼
FinderContext:
   Finder frontmost?  ──no──► pass through
   editing text (AX focus == text field)? ──yes──► pass through
   │ no
   ▼
Remap(keycode, flags) → decision
   ├─ .passThrough                → return event unchanged
   └─ .send([keys])               → swallow original, post synthetic keys
```

### Components (small, single-purpose files)

- **`Remap.swift`** — Pure function, no system calls:
  `remap(keyCode: CGKeyCode, flags: CGEventFlags) -> RemapAction`
  where `RemapAction = .passThrough | .send([SyntheticKey])`.
  This is where the entire remap table lives, and it is fully unit-testable in isolation.

- **`FinderContext.swift`** — Answers two questions behind a protocol so it can be mocked:
  - `isFinderFrontmost()` → `NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder"`.
  - `isEditingText()` → build `AXUIElementCreateApplication(finderPID)`, read `kAXFocusedUIElementAttribute`, read its `kAXRoleAttribute`; return `true` if it is `kAXTextFieldRole` or `kAXTextAreaRole` (mid-rename / search field). If AX read fails, default to `true` (fail safe: never hijack a possible rename).

- **`KeyTap.swift`** — Owns the `CGEventTap`:
  - Created at `.cgSessionEventTap`, `.headInsertEventTap`, mask = `keyDown`.
  - Callback consults `FinderContext` + `Remap`, then either returns the event or returns `nil` and posts synthetic events.
  - Re-enables itself on `.tapDisabledByTimeout` / `.tapDisabledByUserInput`.
  - Tags every synthetic event it posts via a dedicated `CGEventSource` + a sentinel value in `.eventSourceUserData`; the callback ignores any event carrying that sentinel (prevents infinite re-processing loops).
  - Ignores autorepeat (`.keyboardEventAutorepeat`) for the destructive keys.

- **`Permissions.swift`** — `AXIsProcessTrusted()` check; opens
  `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`;
  drives a short retry so the tap is (re)created once the user grants Accessibility.

- **`LoginItem.swift`** — `SMAppService.mainApp.register()` / `.unregister()`, plus current-status read for the menu checkmark.

- **`MenuBarController.swift`** — `NSStatusItem` with a deliberately tiny menu:
  - Permission status line ("Accessibility: granted / needs permission").
  - "Open Accessibility Settings…"
  - "Launch at Login" (toggle, ✓ when registered).
  - "Quit".

- **`PresButanRebornApp.swift`** — Entry point. `NSApplication` with
  `setActivationPolicy(.accessory)`; wires the components together; kicks off the
  permission check → tap creation flow.

## 4. Error handling & edge cases

- **Accessibility not granted:** event tap creation returns `nil`. Show the "needs permission" menu state and poll `AXIsProcessTrusted()` (or re-check on app-activation) to auto-recover once granted.
- **Tap disabled by system:** re-enable inside the callback.
- **Synthetic-event feedback loop:** guarded by the source-tag sentinel described above.
- **Modifier hygiene:** when deciding "no modifiers," mask the event flags down to the significant set (⌘ ⌥ ⌃ ⇧) and ignore Caps Lock (`maskAlphaShift`), Fn (`maskSecondaryFn`), and non-coalesced/device bits. "Open" requires the significant set to be empty; "Delete Immediately" requires it to be exactly Shift.
- **No selection:** `⌘O` / `⌘⌫` simply no-op in Finder — no special handling needed, so we deliberately do **not** try to detect selection state (keeps AX logic minimal and robust).
- **International layouts:** we match physical key codes, which are layout-independent (Return = 36 everywhere).
- **Fail-safe on AX failure:** if we can't read focus state, treat it as "editing" and pass through, so we never break a rename.

## 5. Testing

- **Unit tests (`RemapTests.swift`)** — cover every row of the remap table plus pass-through cases: bare Return → ⌘O; Keypad Enter → ⌘O; Delete/Forward Delete → ⌘⌫; Shift+Delete → ⌘⌥⌫; ⌘+Return, ⌥+Delete, Caps-Lock+Return, arbitrary letters → pass through. `Remap` is pure, so this is the real coverage target.
- **`FinderContext` seam** — protocol-backed so remap-decision tests inject fake "frontmost/editing" states without touching the real system.
- **Manual QA checklist (in README/CI notes):**
  1. Rename a file, press Return → rename commits (not opened).
  2. Select a file, press Return → opens.
  3. Select a folder, press Return → opens/navigates.
  4. Select a file, press Delete → moves to Trash.
  5. Shift+Delete → native confirm dialog appears; confirming deletes.
  6. Focus Finder's search field, type + Enter → normal search behavior (not hijacked).
  7. Switch to another app (e.g. TextEdit) → Return/Delete behave normally.

## 6. Build & distribution

- **Toolchain:** SwiftPM executable target linking AppKit + ApplicationServices. A `scripts/build-dmg.sh` assembles the `.app` bundle (writes `Info.plist` with `LSUIElement=YES`, `LSMinimumSystemVersion=13.0`), then produces a DMG. This keeps everything as reviewable plain-text files rather than an opaque `.xcodeproj`.
- **Signing (decided): unsigned first, notarize later.**
  - Initial releases ship **unsigned**. README documents the one-time Gatekeeper bypass (right-click → Open, or `xattr -dr com.apple.quarantine "/Applications/PresButan Reborn.app"`).
  - Leave a clearly marked hook in `build-dmg.sh` / the release workflow for Developer ID signing + `notarytool` to be enabled later once an Apple Developer account is available.
- **Repo:** GPL-3.0 license; README with what/why, screenshots, the Accessibility-grant walkthrough, and the Gatekeeper note; a GitHub Actions workflow (`.github/workflows/release.yml`) that builds the DMG and attaches it to tagged releases.
- **Launch:** eventual Reddit share (r/macapps) once a tagged release with a downloadable DMG exists.

## 7. Proposed repo structure

```
presbutan_reborn/
├── README.md
├── LICENSE
├── Package.swift
├── Sources/PresButanReborn/
│   ├── PresButanRebornApp.swift
│   ├── MenuBarController.swift
│   ├── KeyTap.swift
│   ├── FinderContext.swift
│   ├── Remap.swift
│   ├── Permissions.swift
│   └── LoginItem.swift
├── Tests/PresButanRebornTests/
│   └── RemapTests.swift
├── scripts/
│   └── build-dmg.sh
├── Resources/
│   └── Info.plist
└── .github/workflows/
    ├── ci.yml          # build + test on push
    └── release.yml     # build DMG on tag
```

## 8. Open questions / assumptions

- **App name:** "PresButan Reborn" (matches the working directory) — trivially renameable before first release.
- **Menu-bar icon art:** placeholder SF Symbol (e.g. `return`) for v1; a custom template icon can follow.
- **Apple Developer account:** assumed absent for now (drives the unsigned-first decision); revisit for notarization when available.

## Key codes reference (appendix)

| Key | `CGKeyCode` |
|---|---|
| Return | 36 |
| Keypad Enter | 76 |
| Delete (Backspace) | 51 |
| Forward Delete | 117 |
| O | 31 |

Synthetic outputs: Open = `O`+⌘ · Trash = `Delete`+⌘ · Delete Immediately = `Delete`+⌘+⌥.
