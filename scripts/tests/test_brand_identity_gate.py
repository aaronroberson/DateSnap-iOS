#!/usr/bin/env python3
"""Regression tests for the brand identity gate."""

from __future__ import annotations

import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
GATE = ROOT / "scripts" / "verify-brand-identity.py"
LEGACY = "Date" + "Snap"


class BrandIdentityGateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory(prefix="brand-gate-test-")
        self.repo = Path(self.temp_dir.name)
        subprocess.run(["git", "init", "-q", str(self.repo)], check=True)
        subprocess.run(["git", "-C", str(self.repo), "config", "user.name", "Gate Test"], check=True)
        subprocess.run(["git", "-C", str(self.repo), "config", "user.email", "gate@example.invalid"], check=True)
        (self.repo / "scripts").mkdir()
        target = self.repo / "scripts" / GATE.name
        target.write_bytes(GATE.read_bytes())
        self.clean_file = self.repo / "README.md"
        self.clean_file.write_text("Pencil'd and Pencild are the supported brand names.\n")
        subprocess.run(["git", "-C", str(self.repo), "add", "."], check=True)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def run_gate(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["python3", str(self.repo / "scripts" / GATE.name), *args],
            cwd=self.repo,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )

    def test_clean_worktree_passes(self) -> None:
        result = self.run_gate("--worktree")
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_legacy_content_is_rejected_in_worktree(self) -> None:
        self.clean_file.write_text(f"Old project reference: {LEGACY}.xcodeproj\n")
        result = self.run_gate("--worktree")
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("legacy identity in file", result.stdout)

    def test_legacy_staged_content_is_rejected(self) -> None:
        self.clean_file.write_text(f"Old project reference: {LEGACY}.xcodeproj\n")
        subprocess.run(["git", "-C", str(self.repo), "add", "README.md"], check=True)
        result = self.run_gate("--staged")
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("legacy identity in file", result.stdout)

    def test_legacy_staged_filename_is_rejected(self) -> None:
        bad_file = self.repo / f"{LEGACY}-notes.txt"
        bad_file.write_text("Pencild documentation.\n")
        subprocess.run(["git", "-C", str(self.repo), "add", "."], check=True)
        result = self.run_gate("--staged")
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("legacy identity in path", result.stdout)


if __name__ == "__main__":
    unittest.main()
