#!/usr/bin/env python3
"""Writes the Homebrew cask for a release.

  update_cask.py --version 0.2.0-dev.12 --sha256 <hex> --repo ryan-stoffel/hush --output Casks/hush-dictation.rb
"""

from __future__ import annotations

import argparse
from pathlib import Path

TEMPLATE = '''cask "hush-dictation" do
  version "{version}"
  sha256 "{sha256}"

  url "https://github.com/{repo}/releases/download/v#{{version}}/Hush-#{{version}}.zip"
  name "Hush"
  desc "Menu bar voice dictation that works in every app, on-device by default"
  homepage "https://github.com/{repo}"

  depends_on macos: :sonoma

  app "Hush.app"

  uninstall quit: "io.github.ryan-stoffel.hush"

  zap trash: [
    "~/Library/Application Support/Hush",
    "~/Library/Preferences/io.github.ryan-stoffel.hush.plist",
    "~/Library/Saved Application State/io.github.ryan-stoffel.hush.savedState",
  ]

  caveats <<~EOS
{caveat}

    Hush asks for Microphone, Accessibility, and Input Monitoring on first use:
    the microphone to hear you, Accessibility to paste the text at your cursor,
    and Input Monitoring to notice the Fn key while another app is in front.
    Open Hush from the menu bar and use the Grant buttons in its popover.
  EOS
end
'''

CAVEAT_UNSIGNED = """\
    Hush is not notarized yet, so macOS blocks the first launch of a downloaded copy.

      After install: xattr -dr com.apple.quarantine /Applications/Hush.app
      Or:            open Hush once, then System Settings > Privacy & Security > Open Anyway.

    Homebrew 7 removed --no-quarantine, so repeat the xattr step after each upgrade."""
CAVEAT_NOTARIZED = """\
    Hush is signed with a Developer ID and notarized by Apple."""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--notarized", action="store_true")
    args = parser.parse_args()
    text = TEMPLATE.format(
        version=args.version,
        sha256=args.sha256,
        repo=args.repo,
        caveat=CAVEAT_NOTARIZED if args.notarized else CAVEAT_UNSIGNED,
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(text)
    print(f"Wrote {args.output} for {args.version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
