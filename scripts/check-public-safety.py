#!/usr/bin/env python3
"""Fail when public skill files contain likely secrets or private context."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN_BASENAMES = {
    "private-context.md",
    "private-context.template.md",
    ".env",
    "auth.json",
}
SKIP_PARTS = {".git", "__pycache__"}

PATTERNS = {
    "private IPv4 address": re.compile(
        r"(?<![\d.])(?:"
        r"10(?:\.\d{1,3}){3}|"
        r"172\.(?:1[6-9]|2\d|3[01])(?:\.\d{1,3}){2}|"
        r"192\.168(?:\.\d{1,3}){2}|"
        r"169\.254(?:\.\d{1,3}){2}"
        r")(?![\d.])"
    ),
    "email address": re.compile(
        r"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"
    ),
    "MAC address": re.compile(r"(?i)\b(?:[0-9a-f]{2}:){5}[0-9a-f]{2}\b"),
    "private key": re.compile(
        r"-----BEGIN (?:OPENSSH|RSA|EC|DSA|PGP) PRIVATE KEY-----"
    ),
    "GitHub token": re.compile(
        r"\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b"
    ),
    "AWS access key": re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
    "JWT": re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"),
    "known private domain": re.compile(
        r"(?i)\b(?:[A-Za-z0-9-]+\.)*(?:"
        + r"1al"
        + r"\.cc|"
        + r"cold"
        + r"\.haus)\b"
    ),
}


def candidate_files() -> list[Path]:
    try:
        result = subprocess.run(
            [
                "git",
                "-C",
                str(ROOT),
                "ls-files",
                "--cached",
                "--others",
                "--exclude-standard",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        paths = [ROOT / line for line in result.stdout.splitlines() if line]
    except (OSError, subprocess.CalledProcessError):
        paths = [path for path in ROOT.rglob("*") if path.is_file()]
    return sorted(
        path
        for path in paths
        if path.is_file() and not any(part in SKIP_PARTS for part in path.parts)
    )


def main() -> int:
    findings: list[str] = []
    for path in candidate_files():
        rel = path.relative_to(ROOT)
        if path.name in FORBIDDEN_BASENAMES:
            findings.append(f"{rel}: forbidden private-context/credential filename")
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        for line_number, line in enumerate(text.splitlines(), 1):
            for label, pattern in PATTERNS.items():
                if pattern.search(line):
                    findings.append(f"{rel}:{line_number}: {label}")

    if findings:
        print("Public-safety scan failed:", file=sys.stderr)
        for finding in findings:
            print(f"  - {finding}", file=sys.stderr)
        return 1

    print(f"Public-safety scan passed ({len(candidate_files())} files checked).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
