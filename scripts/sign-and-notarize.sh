#!/usr/bin/env bash
# Signs an exported .app with a Developer ID identity, notarizes it, and staples the ticket.
# usage: sign-and-notarize.sh <path-to-app> <entitlements-plist>
# Required environment: DEVELOPER_ID_IDENTITY, NOTARY_APPLE_ID, NOTARY_TEAM_ID, NOTARY_PASSWORD
set -euo pipefail

APP="$1"
ENTITLEMENTS="$2"
: "${DEVELOPER_ID_IDENTITY:?}" "${NOTARY_APPLE_ID:?}" "${NOTARY_TEAM_ID:?}" "${NOTARY_PASSWORD:?}"

sign() {
  codesign --force --timestamp --options runtime --sign "$DEVELOPER_ID_IDENTITY" "$@"
}

# Nested code is signed from the inside out. Sparkle ships helpers that need their own pass.
if [ -d "$APP/Contents/Frameworks" ]; then
  find "$APP/Contents/Frameworks" -type d \( -name "*.xpc" -o -name "*.app" \) -print0 | while IFS= read -r -d '' nested; do
    sign "$nested"
  done
  find "$APP/Contents/Frameworks" -type f -perm +111 -name "Autoupdate" -print0 | while IFS= read -r -d '' nested; do
    sign "$nested"
  done
  find "$APP/Contents/Frameworks" -maxdepth 1 \( -name "*.framework" -o -name "*.dylib" \) -print0 | while IFS= read -r -d '' nested; do
    sign "$nested"
  done
fi
sign --entitlements "$ENTITLEMENTS" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

SUBMISSION="$(mktemp -d)/submission.zip"
ditto -c -k --keepParent "$APP" "$SUBMISSION"
xcrun notarytool submit "$SUBMISSION" \
  --apple-id "$NOTARY_APPLE_ID" \
  --team-id "$NOTARY_TEAM_ID" \
  --password "$NOTARY_PASSWORD" \
  --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"
