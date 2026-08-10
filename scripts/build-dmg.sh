#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PresButan Reborn"
EXECUTABLE="PresButanReborn"
CONFIG="release"
OUT="build"

# Signing identity. Auto-detected from the keychain when present; override with
# SIGN_IDENTITY=... to pick a specific one. Falls back to ad-hoc so the build
# still works on machines without the certificate (CI runners, contributors).
SIGN_IDENTITY="${SIGN_IDENTITY:-$(
    security find-identity -v -p codesigning 2>/dev/null \
        | grep "Developer ID Application" | head -1 \
        | sed -E 's/.*"(.*)".*/\1/'
)}"

# Optional notarization: set NOTARY_PROFILE to a profile created once with
#   xcrun notarytool store-credentials <name> --apple-id … --team-id … --password …
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

echo "==> Building ($CONFIG)…"
swift build -c "$CONFIG"

BIN=".build/${CONFIG}/${EXECUTABLE}"
APP_DIR="${OUT}/${APP_NAME}.app"

echo "==> Assembling ${APP_DIR}…"
rm -rf "$APP_DIR"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "$BIN" "${APP_DIR}/Contents/MacOS/${EXECUTABLE}"
cp "Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"
cp "Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"

# Why the identity matters beyond Gatekeeper: macOS keys the Accessibility (TCC)
# grant to the app's code identity. An ad-hoc signature has no stable identity —
# its designated requirement is the cdhash, which changes on every build, so the
# user must re-authorise the app after each update. A Developer ID signature
# pins the requirement to the team, and the grant survives updates.
if [ -n "$SIGN_IDENTITY" ]; then
    echo "==> Signing with: ${SIGN_IDENTITY}"
    # No --deep: it is deprecated for signing, and this bundle has no nested code.
    # --options runtime and --timestamp are both required for notarization.
    codesign --force --options runtime --timestamp \
        --sign "$SIGN_IDENTITY" "$APP_DIR"
else
    echo "==> WARNING: no Developer ID Application identity found — ad-hoc signing."
    echo "    Gatekeeper will warn on download, and users will have to re-grant"
    echo "    Accessibility after every update."
    codesign --force --sign - "$APP_DIR"
fi

codesign --verify --strict --verbose "$APP_DIR"
echo "==> Designated requirement (what TCC remembers):"
codesign -d --requirements - "$APP_DIR" 2>&1 | tail -1

# Notarize and staple the .app itself, before it goes into the disk image.
# Stapling only the DMG leaves the app ticketless once dragged to /Applications,
# forcing Gatekeeper to ask Apple online at first launch — which fails offline.
if [ -n "$NOTARY_PROFILE" ]; then
    ZIP="${OUT}/${EXECUTABLE}-app.zip"
    echo "==> Notarizing the app…"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP_DIR" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP_DIR"
    xcrun stapler validate "$APP_DIR"
    rm -f "$ZIP"
fi

DMG="${OUT}/${EXECUTABLE}.dmg"
echo "==> Creating ${DMG}…"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_DIR" -ov -format UDZO "$DMG"

# The disk image needs its own signature, and it must be applied *before*
# notarization — signing afterwards would invalidate the stapled ticket. Without
# this the DMG carries a ticket but no signature, and `spctl --assess` rejects it
# with "no usable signature" even though the app inside is perfectly signed.
if [ -n "$SIGN_IDENTITY" ]; then
    echo "==> Signing the disk image…"
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
fi

if [ -n "$NOTARY_PROFILE" ]; then
    echo "==> Notarizing (this waits on Apple, usually a few minutes)…"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    echo "==> Stapling…"
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
    echo "==> Gatekeeper verdict (this is what a downloader gets):"
    spctl --assess --type open --context context:primary-signature -v "$DMG"
else
    echo "==> Skipping notarization (NOTARY_PROFILE unset)."
fi

echo "==> Done: $DMG"
