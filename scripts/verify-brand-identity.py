#!/usr/bin/env python3
"""Reject reintroduced legacy brand text and filenames in repository files."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import subprocess
import sys

# Build the match from fragments so the forbidden spelling is not itself
# embedded in this gate's source.
LEGACY_PATTERN = re.compile(re.escape("Date" + "Snap"), re.IGNORECASE)
LEGACY_BYTES = re.compile(b"Date" + b"Snap", re.IGNORECASE)
EXCLUDED_PARTS = {
    ".git",
    ".build",
    "build",
    "DerivedData",
    "lancedb",
    "graphify-out",
    "node_modules",
}


def git(*args: str, input_bytes: bytes | None = None) -> bytes:
    result = subprocess.run(
        ["git", *args],
        input=input_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode:
        sys.stderr.write(result.stderr.decode("utf-8", "replace"))
        raise RuntimeError(f"git {' '.join(args)} failed with exit {result.returncode}")
    return result.stdout


def repository_root() -> Path:
    return Path(os.fsdecode(git("rev-parse", "--show-toplevel").rstrip(b"\n")))


def included(path: bytes) -> bool:
    parts = Path(os.fsdecode(path)).parts
    return not any(part in EXCLUDED_PARTS for part in parts)


def check_path(path: bytes, findings: list[str]) -> None:
    if LEGACY_BYTES.search(path):
        findings.append(f"legacy identity in path: {os.fsdecode(path)}")


def check_content(path: bytes, content: bytes, findings: list[str]) -> None:
    if LEGACY_BYTES.search(content):
        findings.append(f"legacy identity in file: {os.fsdecode(path)}")


def worktree_files(root: Path) -> list[bytes]:
    raw = git("ls-files", "--cached", "--others", "--exclude-standard", "-z")
    return [path for path in raw.split(b"\0") if path and included(path)]


def check_worktree(root: Path, findings: list[str]) -> None:
    for relative in worktree_files(root):
        check_path(relative, findings)
        path = root / os.fsdecode(relative)
        try:
            if path.is_file():
                check_content(relative, path.read_bytes(), findings)
        except OSError as error:
            findings.append(f"could not inspect {os.fsdecode(relative)}: {error}")


def staged_blobs(root: Path) -> list[tuple[bytes, bytes]]:
    entries = git("ls-files", "--stage", "-z").split(b"\0")
    blobs: list[tuple[bytes, bytes]] = []
    object_ids: list[bytes] = []
    paths: list[bytes] = []

    for entry in entries:
        if not entry:
            continue
        metadata, path = entry.split(b"\t", 1)
        _, object_id, stage = metadata.split(b" ", 2)
        if stage != b"0":
            raise RuntimeError(f"unmerged index entry: {os.fsdecode(path)}")
        if included(path):
            check_path(path, [])  # Filename checks are reported by the caller.
            object_ids.append(object_id)
            paths.append(path)

    if not object_ids:
        return blobs

    process = subprocess.Popen(
        ["git", "cat-file", "--batch"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    assert process.stdin is not None and process.stdout is not None
    process.stdin.write(b"\n".join(object_ids) + b"\n")
    process.stdin.close()

    for path in paths:
        header = process.stdout.readline().rstrip(b"\n").split(b" ")
        if len(header) != 3 or header[1] != b"blob":
            raise RuntimeError(f"could not read staged blob for {os.fsdecode(path)}")
        size = int(header[2])
        content = process.stdout.read(size)
        if len(content) != size or process.stdout.read(1) != b"\n":
            raise RuntimeError(f"truncated staged blob for {os.fsdecode(path)}")
        blobs.append((path, content))

    stderr = process.stderr.read() if process.stderr is not None else b""
    if process.wait():
        raise RuntimeError(stderr.decode("utf-8", "replace") or "git cat-file failed")
    return blobs


def check_staged(findings: list[str]) -> None:
    for path, content in staged_blobs(repository_root()):
        check_path(path, findings)
        check_content(path, content, findings)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--staged", action="store_true", help="scan the Git index (pre-commit mode)")
    mode.add_argument("--worktree", action="store_true", help="scan tracked and non-ignored untracked files")
    args = parser.parse_args()
    findings: list[str] = []

    try:
        if args.staged:
            check_staged(findings)
        else:
            check_worktree(repository_root(), findings)
    except (OSError, RuntimeError, ValueError) as error:
        print(f"Brand identity gate could not complete: {error}", file=sys.stderr)
        return 2

    if findings:
        print("Brand identity gate failed. Replace the obsolete app name with Pencil'd or Pencild:")
        for finding in findings:
            print(f"  {finding}")
        return 1

    scope = "staged Git index" if args.staged else "tracked and non-ignored working-tree files"
    print(f"Brand identity gate passed ({scope}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
