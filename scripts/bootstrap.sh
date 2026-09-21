#!/usr/bin/env bash
# Installs the command line tools the project needs and generates the Xcode project.
set -euo pipefail
cd "$(dirname "$0")/.."

for tool in xcodegen swiftformat swiftlint; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    if ! command -v brew >/dev/null 2>&1; then
      echo "Missing $tool and Homebrew is not installed. Install $tool and run this again." >&2
      exit 1
    fi
    brew install "$tool"
  fi
done

xcodegen generate
echo "Generated Hush.xcodeproj. Open it in Xcode or use scripts/test.sh."
