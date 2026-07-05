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
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "$BIN" "${APP_DIR}/Contents/MacOS/${EXECUTABLE}"
cp "Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"
cp "Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"

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
