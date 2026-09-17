#!/usr/bin/env python3
"""Cuts a release section in CHANGELOG.md (Keep a Changelog format).

  changelog_release.py cut --version 0.1.0 --date 2026-09-17 --repo owner/name [--fallback-notes FILE]
  changelog_release.py notes --version 0.1.0

cut moves everything under "## [Unreleased]" into a new "## [version] - date"
section and refreshes the compare links. If Unreleased is empty the fallback
notes are used. notes prints the body of an existing version section.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

CHANGELOG = Path("CHANGELOG.md")
UNRELEASED_RE = re.compile(r"^## \[Unreleased\][ \t]*$", re.MULTILINE)
SECTION_RE = re.compile(r"^## \[", re.MULTILINE)
LINK_RE = re.compile(r"^\[[^\]]+\]: https?://\S+\s*$", re.MULTILINE)


def split_links(text: str) -> tuple[str, list[str]]:
    links = [m.group(0).strip() for m in LINK_RE.finditer(text)]
    return LINK_RE.sub("", text).rstrip() + "\n", links


def cut(version: str, date: str, repo: str, fallback: str) -> int:
    text = CHANGELOG.read_text()
    if re.search(r"^## \[%s\]" % re.escape(version), text, re.MULTILINE):
        print(f"CHANGELOG.md already has a section for {version}. Nothing to do.")
        return 0
    body, links = split_links(text)
    heading = UNRELEASED_RE.search(body)
    if not heading:
        print("::error::CHANGELOG.md has no '## [Unreleased]' section.")
        return 1
    rest = body[heading.end():]
    following = SECTION_RE.search(rest)
    unreleased = rest[: following.start()] if following else rest
    tail = rest[following.start():] if following else ""
    entries = unreleased.strip() or fallback.strip() or "### Changed\n\n- Maintenance release."
    new_body = (
        body[: heading.end()]
        + "\n\n"
        + f"## [{version}] - {date}\n\n{entries}\n\n"
        + tail
    )

    previous = None
    for link in links:
        match = re.match(r"^\[(\d[^\]]*)\]:", link)
        if match:
            previous = match.group(1)
            break
    base = f"https://github.com/{repo}"
    kept = [link for link in links if not link.startswith("[Unreleased]:")]
    new_links = [f"[Unreleased]: {base}/compare/v{version}...HEAD"]
    if previous:
        new_links.append(f"[{version}]: {base}/compare/v{previous}...v{version}")
    else:
        new_links.append(f"[{version}]: {base}/releases/tag/v{version}")
    CHANGELOG.write_text(new_body.rstrip() + "\n\n" + "\n".join(new_links + kept) + "\n")
    print(f"Added section {version} to CHANGELOG.md")
    return 0


def notes(version: str) -> int:
    text, _ = split_links(CHANGELOG.read_text())
    heading = re.search(r"^## \[%s\].*$" % re.escape(version), text, re.MULTILINE)
    if not heading:
        return 1
    rest = text[heading.end():]
    following = SECTION_RE.search(rest)
    sys.stdout.write((rest[: following.start()] if following else rest).strip() + "\n")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    cut_parser = sub.add_parser("cut")
    cut_parser.add_argument("--version", required=True)
    cut_parser.add_argument("--date", required=True)
    cut_parser.add_argument("--repo", required=True)
    cut_parser.add_argument("--fallback-notes", type=Path)
    notes_parser = sub.add_parser("notes")
    notes_parser.add_argument("--version", required=True)
    args = parser.parse_args()
    if args.command == "cut":
        fallback = args.fallback_notes.read_text() if args.fallback_notes and args.fallback_notes.exists() else ""
        return cut(args.version, args.date, args.repo, fallback)
    return notes(args.version)


if __name__ == "__main__":
    sys.exit(main())
