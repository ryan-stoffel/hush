#!/usr/bin/env bash
# Notarizes a signed .app and staples the ticket. Needs a Developer ID signature.
# usage: notarize.sh <path-to-app>
# Required environment: NOTARY_APPLE_ID, NOTARY_TEAM_ID, NOTARY_PASSWORD
set -euo pipefail

APP="$1"
: "${NOTARY_APPLE_ID:?}" "${NOTARY_TEAM_ID:?}" "${NOTARY_PASSWORD:?}"

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
