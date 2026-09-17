#!/usr/bin/env python3
"""Pull request rule checks used by CI. Each subcommand exits non-zero on failure.

  check_pr.py title --title-file FILE
  check_pr.py linked-issue --body-file FILE
  check_pr.py before-after --body-file FILE [--require-images]
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

TYPES = ("feat", "fix", "chore", "docs", "refactor", "test", "ci", "build", "perf")
SCOPES = (
    "audio",
    "hotkey",
    "transcription",
    "cleanup",
    "insertion",
    "ui",
    "settings",
    "ci",
    "release",
    "docs",
    "deps",
)
TITLE_RE = re.compile(
    r"^(?P<type>%s)\((?P<scope>%s)\): (?P<summary>\S.*)$" % ("|".join(TYPES), "|".join(SCOPES))
)
ISSUE_RE = re.compile(r"\b(?:closes|fixes)\s+#(\d+)\b", re.IGNORECASE)
SECTION_RE = re.compile(r"^##\s+Before and After\s*$", re.IGNORECASE | re.MULTILINE)
NEXT_SECTION_RE = re.compile(r"^##\s+", re.MULTILINE)
IMAGE_RE = re.compile(r"!\[[^\]]*\]\(https?://[^)\s]+\)")
COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
WAIVER = "no ui change"
START = "<!-- screenshots:start -->"
END = "<!-- screenshots:end -->"


def fail(message: str) -> int:
    print(f"::error::{message}")
    return 1


def check_title(title: str) -> int:
    title = title.strip()
    match = TITLE_RE.match(title)
    if not match:
        return fail(
            f"Title '{title}' must look like type(scope): summary. "
            f"Types: {', '.join(TYPES)}. Scopes: {', '.join(SCOPES)}."
        )
    summary = match.group("summary")
    if summary.endswith("."):
        return fail("Title summary must not end with a period.")
    if summary[0].isupper():
        return fail("Title summary must start with a lowercase letter.")
    print(f"Title ok: {title}")
    return 0


def check_linked_issue(body: str) -> int:
    visible = COMMENT_RE.sub("", body)
    match = ISSUE_RE.search(visible)
    if not match:
        return fail("PR body must contain 'Closes #<number>' or 'Fixes #<number>'.")
    print(f"Linked issue: #{match.group(1)}")
    return 0


def before_after_section(body: str) -> str | None:
    heading = SECTION_RE.search(body)
    if not heading:
        return None
    rest = body[heading.end():]
    following = NEXT_SECTION_RE.search(rest)
    return rest[: following.start()] if following else rest


def check_before_after(body: str, require_images: bool) -> int:
    section = before_after_section(body)
    if section is None:
        return fail("PR body must contain a '## Before and After' section.")
    has_markers = START in section and END in section
    visible = COMMENT_RE.sub("", section)
    has_images = bool(IMAGE_RE.search(visible))
    waived = WAIVER in visible.lower()
    if has_images:
        print("Before and After section contains embedded screenshots.")
        return 0
    if waived:
        print("Before and After section is waived with 'No UI change'.")
        return 0
    if has_markers and not require_images:
        print("Screenshot markers present. The screenshots workflow fills them in.")
        return 0
    return fail(
        "The Before and After section needs embedded screenshots (CI inserts them between the "
        "screenshots markers) or the text 'No UI change'."
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    title = sub.add_parser("title")
    title.add_argument("--title-file", type=Path, required=True)
    linked = sub.add_parser("linked-issue")
    linked.add_argument("--body-file", type=Path, required=True)
    before_after = sub.add_parser("before-after")
    before_after.add_argument("--body-file", type=Path, required=True)
    before_after.add_argument("--require-images", action="store_true")
    args = parser.parse_args()

    if args.command == "title":
        return check_title(args.title_file.read_text())
    if args.command == "linked-issue":
        return check_linked_issue(args.body_file.read_text())
    return check_before_after(args.body_file.read_text(), args.require_images)


if __name__ == "__main__":
    sys.exit(main())
