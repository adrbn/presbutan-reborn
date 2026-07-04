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
