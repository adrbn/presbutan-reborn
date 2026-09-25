<p align="center">
  <img src="docs/assets/icon.png" width="128" height="128" alt="PresButan Reborn" />
</p>

<h1 align="center">PresButan Reborn</h1>

<p align="center">
  <b>Return opens. Delete trashes.</b><br>
  Finder keys the way Windows does them, for everyone who switched to the Mac<br>
  and still reaches for them. Free, open source, native to macOS.
</p>

<p align="center">
  <a href="https://github.com/adrbn/presbutan-reborn/releases/latest"><img src="docs/assets/buttons/download.svg" height="64" alt="Download for macOS, free, macOS 13 Ventura or later"></a>
  &nbsp;
  <a href="https://ko-fi.com/adrbn"><img src="docs/assets/buttons/kofi.svg" height="64" alt="Buy me a coffee on Ko-fi"></a>
  &nbsp;
  <a href="https://github.com/adrbn/presbutan-reborn/issues/new"><img src="docs/assets/buttons/feedback.svg" height="64" alt="Suggest a feature or report a bug"></a>
</p>

<p align="center">
  <a href="https://github.com/adrbn/presbutan-reborn/releases/latest"><img src="https://img.shields.io/github/v/release/adrbn/presbutan-reborn?style=for-the-badge&label=version&color=2D55DB&labelColor=1e1e2e&logo=github&logoColor=white" alt="Latest version"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-63A2FF?style=for-the-badge&logo=apple&logoColor=white&labelColor=1e1e2e" alt="macOS 13 Ventura or later">
  <img src="https://img.shields.io/badge/Finder%20only-no%20tracking-14b8a6?style=for-the-badge&labelColor=1e1e2e" alt="Only touches Finder, no tracking">
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-f59e0b?style=for-the-badge&labelColor=1e1e2e" alt="License: GPL-3.0"></a>
</p>

<p align="center">
  <a href="#get-started">Get started</a> ·
  <a href="#the-keys">The keys</a> ·
  <a href="#faq">FAQ</a> ·
  <a href="#support-presbutan-reborn">Support</a>
</p>

---

## Why PresButan Reborn

- ⏎ **Return opens the file.** Select it, press Return, it opens. No more rename field popping up when you meant to open something.
- ⌫ **Delete moves it to the Trash.** No more ⌘ + Delete. <kbd>Shift</kbd> + <kbd>Delete</kbd> deletes for good, and Finder still asks you first.
- 🎯 **Finder only, never while you type.** Renaming a file, typing in the search field, a Spotlight, Raycast or Alfred panel on top: the keys go through untouched. Every other app is left alone.
- 🪶 **Invisible.** No Dock icon and no window. Hide the menu-bar icon too if you like.
- 🔒 **Your keystrokes stay on your Mac.** It only looks at which key you pressed while Finder is in front. Nothing is logged or stored.
- 💸 **Free, signed and notarized.** No trial, no paid tier, and the code is open source (GPL-3.0). The Accessibility permission survives updates, so you grant it once.

## Get started

1. **[Download PresButan Reborn](https://github.com/adrbn/presbutan-reborn/releases/latest)**, open the `.dmg` and drag it to Applications.
2. **Open it** and allow it in **System Settings ▸ Privacy & Security ▸ Accessibility**.
3. **Select a file in Finder and press Return.** That's it.

> [!TIP]
> Click the <kbd>⏎</kbd> icon in the menu bar to turn on **Launch at Login**, so it's there after every restart.

## The keys

| In Finder, press | What happens | What macOS does without it |
| --- | --- | --- |
| <kbd>Return</kbd> or <kbd>Enter</kbd> | **Opens** the selection | Starts renaming it |
| <kbd>Delete</kbd> | **Moves** the selection to the Trash | Nothing (it wants <kbd>⌘</kbd> + <kbd>Delete</kbd>) |
| <kbd>Shift</kbd> + <kbd>Delete</kbd> | **Deletes it immediately**, after Finder's own confirmation | Nothing |

Everything else, including every shortcut with <kbd>⌘</kbd>, <kbd>⌥</kbd> or <kbd>⌃</kbd>, works exactly as before.

## FAQ

<details>
<summary><b>How do I rename a file now?</b></summary>

Click the name of a selected file (or right-click ▸ **Rename**). Once the name is editable, type and press Return to confirm, as usual. PresButan Reborn steps aside whenever a text field has the focus.
</details>

<details>
<summary><b>Why does it need Accessibility access?</b></summary>

It's how macOS lets an app see the keys you press, and it's also how PresButan Reborn checks whether you're typing in a text field before it touches a key. macOS enforces that permission, and you can revoke it at any time in System Settings.
</details>

<details>
<summary><b>Does it send anything anywhere?</b></summary>

Your keystrokes, never. The only network request is a once-a-day check on GitHub for a newer version, which only shows up when one exists. There's no analytics and no account. The whole source is right here if you want to check.
</details>

<details>
<summary><b>I used the original PresButan. Is this the same app?</b></summary>

It does the same job, but it's a from-scratch rewrite on current macOS APIs by a different developer. The original has had no update since 2012 and stopped working on macOS 27. If you still have it installed, quit it and remove it so the two don't both handle the keys.
</details>

<details>
<summary><b>Where did the menu-bar icon go?</b></summary>

You probably checked **Hide Menu Bar Icon**. The app keeps running in the background. Open PresButan Reborn again from Applications or Spotlight and the icon comes back for that session. Uncheck the option in its menu to keep it visible.
</details>

<details>
<summary><b>How do I uninstall it?</b></summary>

Choose **Quit PresButan Reborn** in its menu, drag the app from Applications to the Trash, and remove it from **System Settings ▸ Privacy & Security ▸ Accessibility**.
</details>

Found a bug or have an idea? [Open an issue](https://github.com/adrbn/presbutan-reborn/issues). Every report gets read.

## Support PresButan Reborn

PresButan Reborn is free and will stay free. If it saved your pinky a few thousand ⌘ presses, you can **[buy me a coffee on Ko-fi](https://ko-fi.com/adrbn)** ☕. A ⭐ on the repo helps other switchers find it too.

<details>
<summary><b>Build it from source</b></summary>

Requires macOS 13+ and Swift 5.9+ (Xcode 15 or later).

```bash
git clone https://github.com/adrbn/presbutan-reborn.git && cd presbutan-reborn
swift test               # the unit tests
./scripts/build-dmg.sh   # build/PresButanReborn.dmg
```

`build-dmg.sh` signs with a **Developer ID Application** identity when your keychain has one and falls back to ad-hoc signing otherwise. An ad-hoc build works, but macOS asks for the Accessibility permission again after every rebuild. Always test the packaged `.app`: `swift run` starts the bare executable without the bundle's `Info.plist`, so the menu-bar agent and Launch at Login don't behave as they do once installed.

How it works in one paragraph: a background agent installs a `CGEventTap`. When Finder is in front and no text field has the focus (read through the Accessibility API, which fails safe), it swallows the key and posts the matching Finder shortcut: Return becomes ⌘O, Delete becomes ⌘⌫, Shift + Delete becomes ⌘⌥⌫. It also compares the frontmost app with the owner of the focused element, so a Spotlight or Raycast panel keeps its keys. The key mapping lives in [`Remap.swift`](Sources/PresButanReborn/Remap.swift).

Releases are signed, notarized and published with `./scripts/release.sh <version>`.
</details>

## License

[GPL-3.0](LICENSE) © 2026 adrbn. You can use, study, change and share PresButan Reborn, but anything you distribute that is built on it must stay open source under the same license. PresButan Reborn is an independent project and is not affiliated with the original PresButan.
