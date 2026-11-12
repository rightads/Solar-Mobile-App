"""Runs the adversarial API suite (security_tests/security_suite.py) in a clean process.

The suite boots the real FastAPI app against an in-memory MongoDB (mongomock)
and attacks it: account takeover, phone hijack, brute force, token forgery,
IDOR across every resource, privilege escalation, NoSQL injection, mass
assignment, malicious uploads and the full workflow hand-off.
"""
import subprocess
import sys
from pathlib import Path


def test_security_suite_passes():
    backend = Path(__file__).resolve().parents[1]
    proc = subprocess.run(
        [sys.executable, str(backend / "security_tests" / "security_suite.py"), str(backend)],
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=900,
    )
    failures = [line for line in proc.stdout.splitlines() if line.startswith("FAIL")]
    assert proc.returncode == 0, "\n".join(failures) or proc.stderr[-2000:]
