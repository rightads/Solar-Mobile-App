"""Runs the inventory end-to-end suite (security_tests/inventory_suite.py) in a clean process.

The suite boots the real FastAPI app against an in-memory MongoDB (mongomock)
and exercises access control, serial tracking, stock limits and warranty lookups.
"""
import os
import subprocess
import sys
from pathlib import Path


def test_inventory_suite_passes():
    backend = Path(__file__).resolve().parents[1]
    proc = subprocess.run(
        [sys.executable, str(backend / "security_tests" / "inventory_suite.py"), str(backend)],
        capture_output=True,
        text=True,
        encoding="utf-8",
        env={**os.environ, "PYTHONIOENCODING": "utf-8"},
        timeout=900,
    )
    failures = [line for line in proc.stdout.splitlines() if line.startswith("FAIL")]
    assert proc.returncode == 0, "\n".join(failures) or proc.stderr[-2000:]
