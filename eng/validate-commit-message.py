#!/usr/bin/env python3
"""コミットメッセージの形の検査（GIT-003）。commit-msg フックと `make check` が同じこの検証器を使う。

    python3 eng/validate-commit-message.py --file .git/COMMIT_EDITMSG
    python3 eng/validate-commit-message.py --range origin/main..HEAD
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys

TYPES = ("feat", "fix", "docs", "refactor", "test", "build", "ci", "chore")
SUBJECT = re.compile(r"^(?:" + "|".join(TYPES) + r")(?:\([a-z0-9-]+\))?!?: (?P<desc>.+) \(#\d+\)$")
JAPANESE = re.compile(r"[぀-ヿ一-鿿]")
MAX_SUBJECT = 100


def problems(message: str) -> list[str]:
    lines = [ln for ln in message.splitlines() if not ln.startswith("#")]
    subject = lines[0] if lines else ""
    found = []
    m = SUBJECT.match(subject)
    if m is None:
        found.append("件名は `<type>(<scope>): <日本語の説明> (#<issue番号>)` の形（type は " + " / ".join(TYPES) + "）")
    elif not JAPANESE.search(m.group("desc")):
        found.append("説明は日本語で書く")
    if len(subject) > MAX_SUBJECT:
        found.append(f"件名は {MAX_SUBJECT} 文字以内（いまは {len(subject)} 文字）")
    if len(lines) > 1 and lines[1].strip():
        found.append("件名と本文の間は空行")
    if "!:" in subject.split(" ", 1)[0] and "BREAKING CHANGE:" not in message:
        found.append("! を付けたらフッタに BREAKING CHANGE: を書く")
    return found


def git(*args: str) -> str:
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--file")
    group.add_argument("--range")
    args = parser.parse_args(argv)
    if args.file:
        with open(args.file, encoding="utf-8") as fh:
            found = problems(fh.read())
        for p in found:
            print(f"GIT-003 {p}", file=sys.stderr)
        return 1 if found else 0
    try:
        shas = git("rev-list", "--reverse", args.range).split()
    except subprocess.CalledProcessError as err:
        print(f"GIT-003 範囲 {args.range} を読めない: {err.stderr.strip()}", file=sys.stderr)
        return 1
    failed = 0
    for sha in shas:
        for p in problems(git("log", "-1", "--format=%B", sha)):
            print(f"GIT-003 {sha[:7]}: {p}", file=sys.stderr)
            failed += 1
    print(f"commits: {len(shas)} 件・違反 {failed} 件")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
