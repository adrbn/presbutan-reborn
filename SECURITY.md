# Security

## Supported versions

Only the [latest release](https://github.com/adrbn/presbutan-reborn/releases/latest) gets fixes.

## Reporting a vulnerability

Please report it privately through
[GitHub's private vulnerability reporting](https://github.com/adrbn/presbutan-reborn/security/advisories/new),
not in a public issue. I'll reply as soon as I can and credit you in the fix
unless you'd rather stay anonymous.

## What PresButan Reborn does with your keystrokes

It reads the key code and modifier flags of each key-down event to decide
whether to replace it with a Finder shortcut. It only acts while Finder is the
frontmost app and no text field has the focus. Keystrokes are never logged,
stored or sent anywhere.

The only network request is a once-a-day check of
`api.github.com/repos/adrbn/presbutan-reborn/releases/latest` for a newer
version. It carries no identifier and no usage data.
