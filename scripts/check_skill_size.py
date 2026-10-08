#!/usr/bin/env python3
"""Enforce the SKILL.md size target from AGENTS.md.

Fails when any skills/*/SKILL.md exceeds HARD_LIMIT lines. Prints a
non-blocking warning above SOFT_LIMIT lines. Move detailed procedures,
examples, and historical notes into the skill's linked references/ files.

Runs on its own or from scripts/check-public-safety.py.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOFT_LIMIT = 100  # simple-skill target: warn, never fail
HARD_LIMIT = 200  # complex-skill ceiling: fail


def check(root: Path = ROOT) -> tuple[list[str], list[str]]:
    """Return (errors, warnings) for every skills/*/SKILL.md."""
    errors: list[str] = []
    warnings: list[str] = []
    for path in sorted((root / "skills").glob("*/SKILL.md")):
        count = len(path.read_text(encoding="utf-8").splitlines())
        rel = path.relative_to(root)
        if count > HARD_LIMIT:
            errors.append(
                f"{rel}: {count} lines exceeds the {HARD_LIMIT}-line limit; "
                "move detail into linked references/"
            )
        elif count > SOFT_LIMIT:
            warnings.append(
                f"{rel}: {count} lines is above the {SOFT_LIMIT}-line target "
                "for a simple skill (fine if the skill is complex)"
            )
    return errors, warnings


def report(errors: list[str], warnings: list[str]) -> None:
    for warning in warnings:
        print(f"  warning: {warning}", file=sys.stderr)
    if errors:
        print("SKILL.md size check failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
    else:
        print(f"SKILL.md size check passed (limit {HARD_LIMIT} lines, target {SOFT_LIMIT}).")


def main() -> int:
    errors, warnings = check()
    report(errors, warnings)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
