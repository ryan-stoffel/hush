#!/usr/bin/env python3
"""Builds the Before/After screenshot table and splices it into a PR body.

Usage:
  pr_screenshots.py table --before DIR --after DIR --url-prefix URL
  pr_screenshots.py splice --body-file FILE --table-file FILE

The url prefix must point at the folder that contains before/ and after/,
for example https://raw.githubusercontent.com/OWNER/REPO/SHA/pr-12
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

START = "<!-- screenshots:start -->"
END = "<!-- screenshots:end -->"


def images(directory: Path) -> dict[str, Path]:
    if not directory.is_dir():
        return {}
    return {p.stem: p for p in sorted(directory.glob("*.png"))}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build_table(before_dir: Path, after_dir: Path, url_prefix: str) -> str:
    before = images(before_dir)
    after = images(after_dir)
    names = sorted(set(before) | set(after))
    if not names:
        return "_The screenshot suite produced no images for this pull request._"

    prefix = url_prefix.rstrip("/")
    rows = ["| Before | After |", "| --- | --- |"]
    for name in names:
        in_before = name in before
        in_after = name in after
        if in_before:
            left = f"**{name}**<br>![{name} before]({prefix}/before/{name}.png)"
        else:
            left = "New"
        if in_after:
            label = f"**{name}**"
            if in_before and digest(before[name]) == digest(after[name]):
                label += " (identical)"
            right = f"{label}<br>![{name} after]({prefix}/after/{name}.png)"
        else:
            right = "Removed"
        rows.append(f"| {left} | {right} |")
    return "\n".join(rows)


def splice(body: str, table: str) -> str:
    block = f"{START}\n{table}\n{END}"
    start = body.find(START)
    end = body.find(END)
    if start != -1 and end != -1 and end > start:
        return body[:start] + block + body[end + len(END):]
    separator = "" if body.endswith("\n") or not body else "\n"
    return f"{body}{separator}\n## Before and After\n\n{block}\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    table = sub.add_parser("table")
    table.add_argument("--before", type=Path, required=True)
    table.add_argument("--after", type=Path, required=True)
    table.add_argument("--url-prefix", required=True)

    splicer = sub.add_parser("splice")
    splicer.add_argument("--body-file", type=Path, required=True)
    splicer.add_argument("--table-file", type=Path, required=True)

    args = parser.parse_args()
    if args.command == "table":
        sys.stdout.write(build_table(args.before, args.after, args.url_prefix) + "\n")
    else:
        body = args.body_file.read_text() if args.body_file.exists() else ""
        sys.stdout.write(splice(body, args.table_file.read_text().rstrip("\n")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
