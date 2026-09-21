#!/usr/bin/env bash
# scripts/test.sh          unit tests, then UI tests
# scripts/test.sh unit     swift test only
# scripts/test.sh ui       XCUITest screenshot suite only
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-all}"
SCHEME="Hush"
DERIVED_DATA="${DERIVED_DATA_PATH:-$PWD/DerivedData}"

run_unit() {
  swift test
}

run_ui() {
  xcodegen generate --quiet
  rm -rf build/ui-tests.xcresult
  mkdir -p build
  xcodebuild test \
    -project "$SCHEME.xcodeproj" \
    -scheme "$SCHEME" \
    -destination "platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    -resultBundlePath build/ui-tests.xcresult \
    -only-testing:"${SCHEME}UITests" \
    CODE_SIGN_IDENTITY=-
}

case "$MODE" in
  unit) run_unit ;;
  ui) run_ui ;;
  all) run_unit; run_ui ;;
  *) echo "usage: $0 [unit|ui|all]" >&2; exit 64 ;;
esac
