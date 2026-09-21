#!/usr/bin/env bash
# Builds the app found at <source-dir>, runs the XCUITest screenshot suite in demo
# mode, and writes one <window-name>.png per captured window into <output-dir>.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <source-dir> <output-dir>" >&2
  exit 64
fi

SOURCE_DIR="$(cd "$1" && pwd)"
mkdir -p "$2"
OUTPUT_DIR="$(cd "$2" && pwd)"
SCHEME="Hush"
DERIVED_DATA="${DERIVED_DATA_PATH:-$SOURCE_DIR/DerivedData}"
WORK_DIR="$(mktemp -d)"
RESULT_BUNDLE="$WORK_DIR/screenshots.xcresult"

cd "$SOURCE_DIR"
if [ ! -f project.yml ] || [ ! -d UITests ]; then
  echo "No project.yml or UITests directory in $SOURCE_DIR. Nothing to capture."
  exit 0
fi

xcodegen generate --quiet

set +e
xcodebuild test \
  -project "$SCHEME.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  -resultBundlePath "$RESULT_BUNDLE" \
  -only-testing:"${SCHEME}UITests" \
  CODE_SIGN_IDENTITY=- \
  | tee "$WORK_DIR/xcodebuild.log" | grep -E "Test Case|error:|warning: unre|\*\* TEST" 
STATUS=${PIPESTATUS[0]}
set -e

if [ -d "$RESULT_BUNDLE" ]; then
  xcrun xcresulttool export attachments --path "$RESULT_BUNDLE" --output-path "$WORK_DIR/attachments" >/dev/null
  python3 - "$WORK_DIR/attachments" "$OUTPUT_DIR" <<'PY'
import json
import re
import shutil
import sys
from pathlib import Path

source, target = Path(sys.argv[1]), Path(sys.argv[2])
manifest = source / "manifest.json"
pattern = re.compile(r"^(?P<name>.+)_\d+_[0-9A-Fa-f-]{36}\.png$")
count = 0
if manifest.exists():
    for test in json.loads(manifest.read_text()):
        for attachment in test.get("attachments", []):
            match = pattern.match(attachment.get("suggestedHumanReadableName", ""))
            if not match:
                continue
            shutil.copyfile(source / attachment["exportedFileName"], target / f"{match.group('name')}.png")
            count += 1
print(f"Exported {count} screenshots to {target}")
PY
fi

if [ "$STATUS" -ne 0 ]; then
  echo "xcodebuild test exited with $STATUS. Log tail:" >&2
  tail -n 60 "$WORK_DIR/xcodebuild.log" >&2
fi
exit "$STATUS"
