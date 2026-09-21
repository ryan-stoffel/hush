#!/usr/bin/env bash
# Signs an exported .app with the identity in SIGNING_IDENTITY, nested code first.
# usage: sign.sh <path-to-app> <entitlements-plist>
# Any identity works: Developer ID for notarized releases, or an Apple Development or self-signed
# certificate, which is not accepted by Gatekeeper but keeps macOS permission grants stable across builds.
set -euo pipefail

APP="$1"
ENTITLEMENTS="$2"
: "${SIGNING_IDENTITY:?}"

sign() {
  codesign --force --timestamp=none --options runtime --sign "$SIGNING_IDENTITY" "$@"
}

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
