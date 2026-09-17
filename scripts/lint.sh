#!/usr/bin/env bash
# Runs SwiftFormat and SwiftLint. Check mode by default, --fix rewrites files.
set -euo pipefail
cd "$(dirname "$0")/.."

PATHS=(Package.swift App Sources Tests UITests)

if [ "${1:-}" = "--fix" ]; then
  swiftformat "${PATHS[@]}"
  swiftlint lint --fix --quiet
fi

swiftformat --lint "${PATHS[@]}"
swiftlint lint --strict --quiet
