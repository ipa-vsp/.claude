#!/usr/bin/env python3
"""Bucket a git diff by review consequence before you start reading it.

Reads `git diff --numstat` for a commit range and reports: how big the change is,
which files carry the highest consequence (auth, money, migrations, deps, CI,
infra), which are safe to skim (lockfiles, generated, snapshots, vendored), and
whether production code moved without any test file moving with it.

Usage:
  review_scope.py                     # working tree vs HEAD
  review_scope.py HEAD~3              # HEAD~3..HEAD
  review_scope.py origin/main HEAD    # explicit base and head
  review_scope.py origin/main..HEAD   # range syntax
  review_scope.py --repo path/to/repo origin/main

It never writes anything and never touches HEAD, the index, or the working tree.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys

# Path fragments that put a file in the top tier: getting these wrong costs money,
# data, or access, so they get read first and read fully.
HIGH_CONSEQUENCE = [
    (r"auth|login|session|token|password|credential|permission|acl|role|oauth|jwt|crypto|secret",
     "auth / secrets"),
    (r"payment|billing|invoice|charge|refund|price|checkout|subscription|stripe|paypal",
     "money"),
    (r"migration|migrate|schema\.|/schema/|alembic|liquibase|flyway|\.sql$",
     "schema / migration"),
    (r"(^|/)(package|requirements|pyproject|go\.mod|Cargo|Gemfile|composer|pom\.xml|build\.gradle)",
     "dependencies"),
    (r"(^|/)\.github/|(^|/)(Dockerfile|docker-compose|Makefile)|\.tf$|k8s|helm|deploy|(^|/)ci",
     "build / deploy / infra"),
    (r"middleware|cors|csrf|sanitiz|escape|validat",
     "input handling"),
]

# Machine-owned or vendored files: diff size here says nothing about review effort.
LOW_SIGNAL = re.compile(
    r"(lock\.json$|\.lock$|lockb$|(^|/)vendor/|(^|/)node_modules/|\.min\.(js|css)$"
    r"|(^|/)dist/|(^|/)build/|\.snap$|__snapshots__|\.pb\.go$|_pb2\.py$|generated)",
    re.I,
)

TEST_PATH = re.compile(r"(^|/)(tests?|spec|__tests__)/|(^|[._-])(test|spec)([._-]|\.[a-z]+$)", re.I)

# Review-effort thresholds in changed lines (added + deleted), excluding low-signal
# files. Not laws — the point is to decide the reading strategy before reading.
SMALL, MEDIUM, LARGE = 100, 400, 1000


def git(args: list[str], repo: str) -> str:
    try:
        r = subprocess.run(["git", "-C", repo] + args, capture_output=True, text=True)
    except FileNotFoundError:
        sys.exit("error: git is not installed or not on PATH.")
    if r.returncode != 0:
        msg = r.stderr.strip() or "git command failed"
        sys.exit(f"error: {msg}\n  command: git -C {repo} {' '.join(args)}")
    return r.stdout


def classify(path: str) -> tuple[str, str]:
    if LOW_SIGNAL.search(path):
        return "skim", "generated / vendored / lockfile"
    for pattern, label in HIGH_CONSEQUENCE:
        if re.search(pattern, path, re.I):
            return "high", label
    if TEST_PATH.search(path):
        return "test", "test"
    return "normal", ""


def parse_range(tokens: list[str]) -> list[str]:
    """Turn user args into git-diff arguments."""
    if not tokens:
        return []                       # working tree vs HEAD
    if len(tokens) == 1:
        return [tokens[0]] if ".." in tokens[0] else [f"{tokens[0]}..HEAD"]
    if len(tokens) == 2:
        return [f"{tokens[0]}..{tokens[1]}"]
    sys.exit("error: pass at most two revisions (base head) or one range (base..head).")


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Bucket a git diff by review consequence.",
        epilog="Examples: review_scope.py | review_scope.py origin/main HEAD",
    )
    ap.add_argument("revs", nargs="*", help="BASE, BASE HEAD, or BASE..HEAD (default: uncommitted changes)")
    ap.add_argument("--repo", default=".", help="repository path (default: current directory)")
    args = ap.parse_args()

    rev_args = parse_range(args.revs)
    git(["rev-parse", "--git-dir"], args.repo)  # fails loudly if not a repo

    numstat = git(["diff", "--numstat"] + rev_args, args.repo).splitlines()
    if not numstat:
        print("No changes in that range. Check the base revision, or commit first.")
        return 0

    buckets: dict[str, list[tuple[str, int, int, str]]] = {"high": [], "normal": [], "test": [], "skim": []}
    review_lines = 0
    for line in numstat:
        parts = line.split("\t")
        if len(parts) != 3:
            continue
        raw_add, raw_rem, path = parts
        add = int(raw_add) if raw_add.isdigit() else 0   # "-" means binary file
        rem = int(raw_rem) if raw_rem.isdigit() else 0
        bucket, label = classify(path)
        buckets[bucket].append((path, add, rem, label))
        if bucket != "skim":
            review_lines += add + rem

    total_files = sum(len(v) for v in buckets.values())
    print(f"\n{total_files} files changed · {review_lines} lines to actually read "
          f"(excludes generated/vendored)\n")

    if review_lines <= SMALL:
        strategy = "One pass, read every line."
    elif review_lines <= MEDIUM:
        strategy = "Read high-consequence files fully; skim the rest for shape."
    elif review_lines <= LARGE:
        strategy = ("Too big for one honest pass. Review the high-consequence files, "
                    "and state in your review what you did not read.")
    else:
        strategy = ("Ask for a split before reviewing — at this size approvals stop "
                    "correlating with correctness. Offer to pair instead.")
    print(f"Strategy: {strategy}\n")

    titles = {
        "high": "READ FIRST — high consequence",
        "normal": "Normal",
        "test": "Tests",
        "skim": "Skim only — generated / vendored / lockfiles",
    }
    for key in ("high", "normal", "test", "skim"):
        rows = sorted(buckets[key], key=lambda r: -(r[1] + r[2]))
        if not rows:
            continue
        print(f"{titles[key]} ({len(rows)}):")
        for path, add, rem, label in rows:
            suffix = f"  [{label}]" if label and key == "high" else ""
            print(f"  +{add:<5d} -{rem:<5d}  {path}{suffix}")
        print()

    if (buckets["high"] or buckets["normal"]) and not buckets["test"]:
        print("Flag: production code changed, no test file touched. Ask why.\n")
    shrunk = [p for p, add, rem, _ in buckets["test"] if rem > add]
    if shrunk:
        print(f"Flag: test files lost more lines than they gained ({', '.join(shrunk)}). "
              "Check whether coverage was removed.\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
