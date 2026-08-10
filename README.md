<div align="center">

<img src="docs/assets/icon.png" width="128" height="128" alt="PresButan Reborn icon" />

# PresButan Reborn

**Make macOS Finder behave like Windows Explorer.**
Press <kbd>Return</kbd> to open files. Press <kbd>Delete</kbd> to trash them.

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-3B62E4.svg)](LICENSE)
[![CI](https://github.com/adrbn/presbutan-reborn/actions/workflows/ci.yml/badge.svg)](https://github.com/adrbn/presbutan-reborn/actions/workflows/ci.yml)

</div>

---

PresButan Reborn is a tiny, open-source menu-bar utility that restores the Windows-style Finder keys that Mac switchers miss — a modern, maintained successor to the original [PresButan](https://presbutan.macupdate.com/) (last updated 2012).

## Features

| Press | Modifier | Result |
|-------|----------|--------|
| <kbd>Return</kbd> / <kbd>Enter</kbd> | — | **Opens** the selected item (instead of renaming it) |
| <kbd>Delete</kbd> / <kbd>⌫</kbd> | — | **Moves** the selection to Trash |
| <kbd>Delete</kbd> | <kbd>Shift</kbd> | **Deletes immediately** (with Finder's native confirmation) |

- 🪶 **Invisible** — runs as a menu-bar agent with no Dock icon, out of your way. Hide the menu-bar icon too and it disappears entirely until you reopen the app.
- 🎯 **Finder-only & rename-safe** — never fires while you're renaming a file or typing in a text field, and other apps are completely untouched.
- 🔒 **Private by design** — inspects only key-down events and never logs, stores, or transmits keystrokes.
- 🚀 **Launch at Login** and **Check for Updates**, built in.
- ❤️ **Links** to the [GitHub repo](https://github.com/adrbn/presbutan-reborn) and a [Ko-fi donate](https://ko-fi.com/adrbn) page, straight from the menu.
- ⚡ **Native Swift**, zero dependencies, macOS 13 Ventura and later (including macOS 27).

## Why

The original PresButan is abandonware — its last release was in 2012. A 64-bit build kept working for years, but it broke on the move to **macOS 27**, with no maintainer left to fix it. PresButan Reborn is a from-scratch replacement built on current macOS APIs (a keyboard event tap gated by the Accessibility API), so renames still commit correctly and only Finder is affected.

## Install

1. Download `PresButanReborn.dmg` from the [latest release](https://github.com/adrbn/presbutan-reborn/releases/latest).
2. Open the DMG and drag **PresButan Reborn** into `/Applications`.
3. Grant Accessibility so it can remap keys:
   **System Settings → Privacy & Security → Accessibility → enable _PresButan Reborn_.**
4. Use the menu-bar icon (<kbd>⏎</kbd>) to toggle **Launch at Login** or **Check for Updates**.

Builds are signed with Developer ID and notarized, so they open normally — no
Gatekeeper detour. Because the signature carries a stable code identity, the
Accessibility grant also survives updates: you authorise the app once, not again
after every release.

### Hide the menu-bar icon

Want PresButan Reborn to run with zero menu-bar clutter? Open the menu and check **Hide Menu Bar Icon**. The icon vanishes but the app keeps running in the background.

To bring it back, just **open PresButan Reborn again** from `/Applications` or Spotlight — the icon reappears for that session. (The hide preference still applies on the next launch, so the icon stays out of your way across reboots. To show it permanently, uncheck **Hide Menu Bar Icon** from the menu.)

## How it works

PresButan Reborn runs as an `LSUIElement` background agent and installs a `CGEventTap`. When Finder is frontmost **and** you are not editing text, it swallows the key and posts the equivalent Finder shortcut: <kbd>Return</kbd> → ⌘O, <kbd>Delete</kbd> → ⌘⌫, <kbd>Shift</kbd>+<kbd>Delete</kbd> → ⌘⌥⌫.

- **Rename-safe.** It reads Finder's focused UI element through the Accessibility API; if a text field has focus (you're renaming, or typing in search), the key passes straight through. If that state can't be read, it fails safe and does nothing.
- **Overlay-safe.** Spotlight, Raycast and Alfred take the keyboard without becoming the frontmost app, so "Finder is in front" is not enough to claim a key. It compares the frontmost app against the owner of the system-wide focused element and keeps its hands off whenever a panel is holding the keyboard.
- **No feedback loops.** Every synthetic event it posts is tagged and ignored by its own tap.
- **Nothing leaves your Mac.** The tap inspects key codes and modifier flags to make a decision — that's all. The Accessibility permission is the OS-enforced boundary that you control.

## Build from source

```bash
swift build            # compile
swift test             # run the unit tests
./scripts/build-dmg.sh # produce build/PresButanReborn.dmg
```

`build-dmg.sh` picks up a **Developer ID Application** identity from the keychain
automatically and falls back to ad-hoc signing when none is present. Releases are
cut locally rather than in CI, because GitHub runners have no access to the
certificate and an ad-hoc DMG would cost every user a fresh Accessibility grant:

```bash
NOTARY_PROFILE=<profile> ./scripts/build-dmg.sh   # sign + notarize + staple
gh release create vX.Y.Z build/PresButanReborn.dmg --notes "…"
```

Create the notarization profile once with
`xcrun notarytool store-credentials <profile> --apple-id … --team-id …`.

> `swift run` launches the bare executable, which lacks the app bundle's `Info.plist` identity — so `LSUIElement`, Launch at Login, and a stable Accessibility grant only behave correctly from the packaged `.app`. Always QA the installed app.

The app icon is generated from `scripts/make-icon.swift`.

## Roadmap

- [x] Developer ID signing + notarization (remove the Gatekeeper warning)
- [ ] Homebrew cask
- [ ] Optional per-behavior toggles

## Support

PresButan Reborn is free, open-source, and built on evenings. If it saves you time, [a Ko-fi](https://ko-fi.com/adrbn) is very welcome — and stars on [GitHub](https://github.com/adrbn/presbutan-reborn) help others find it.

## Contributing

Issues and pull requests are welcome. The codebase is small and well-tested — start with [`Sources/PresButanReborn/Remap.swift`](Sources/PresButanReborn/Remap.swift) for the core key-mapping logic and its tests.

## License

[GPL-3.0](LICENSE) © PresButan Reborn contributors.
