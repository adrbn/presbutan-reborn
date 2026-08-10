#!/usr/bin/env bash
# Cut a signed, notarized release.
#
#   ./scripts/release.sh 1.0.3
#
# Bumps the version, runs the tests, builds and notarizes the DMG, tags, pushes,
# and publishes the GitHub release with the DMG attached.
#
# It refuses to run rather than ship something subtly broken: no Developer ID
# identity means an ad-hoc build, which costs every user a fresh Accessibility
# grant, so that is treated as a hard error rather than a warning.
set -euo pipefail

VERSION="${1:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-presbutan}"
PLIST="Resources/Info.plist"
DMG="build/PresButanReborn.dmg"

die() { echo "error: $*" >&2; exit 1; }

cd "$(dirname "$0")/.."

# ---------------------------------------------------------------- guardrails

[ -n "$VERSION" ] || die "usage: ./scripts/release.sh <version>   e.g. 1.0.3"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || die "version must look like 1.2.3, got '$VERSION'"

BRANCH=$(git rev-parse --abbrev-ref HEAD)
[ "$BRANCH" = "main" ] || die "on branch '$BRANCH'; releases are cut from main"

[ -z "$(git status --porcelain)" ] \
    || die "working tree is dirty; commit or stash first"

git fetch origin main --quiet
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] \
    || die "local main differs from origin/main; push or pull first"

! git rev-parse "v$VERSION" >/dev/null 2>&1 \
    || die "tag v$VERSION already exists"

CURRENT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
[ "$CURRENT" != "$VERSION" ] || die "$PLIST is already at $VERSION"

security find-identity -v -p codesigning 2>/dev/null | grep -q "Developer ID Application" \
    || die "no Developer ID Application identity in the keychain — an ad-hoc build would force every user to re-grant Accessibility"

xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
    || die "notarization profile '$NOTARY_PROFILE' not found; create it with: xcrun notarytool store-credentials"

command -v gh >/dev/null || die "gh CLI not found"
gh auth status >/dev/null 2>&1 || die "gh is not authenticated; run: gh auth login"

echo "About to release v$VERSION (currently $CURRENT)."
read -r -p "Continue? [y/N] " reply
[[ "$reply" =~ ^[Yy]$ ]] || die "aborted"

# ---------------------------------------------------------------- build

echo "==> Running tests…"
swift test

echo "==> Bumping $PLIST to $VERSION…"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$PLIST"

echo "==> Building, signing and notarizing…"
NOTARY_PROFILE="$NOTARY_PROFILE" ./scripts/build-dmg.sh

# build-dmg.sh already fails on a Gatekeeper rejection; re-assert it here so a
# future edit to that script cannot silently let an unsigned DMG through.
spctl --assess --type open --context context:primary-signature -v "$DMG" \
    || die "Gatekeeper rejected $DMG — refusing to publish"

# ---------------------------------------------------------------- publish

echo "==> Committing, tagging and pushing…"
git add "$PLIST"
git commit -m "chore: release v$VERSION"
git tag -a "v$VERSION" -m "v$VERSION"
git push origin main
git push origin "v$VERSION"

echo "==> Publishing the GitHub release…"
gh release create "v$VERSION" "$DMG" --title "v$VERSION" --generate-notes

echo
echo "Released: $(gh release view "v$VERSION" --json url -q .url)"
echo "Edit the notes if the generated ones need a human pass."
