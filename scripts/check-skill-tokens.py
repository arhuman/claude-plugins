#!/usr/bin/env python3
"""Measure skill Markdown with a pinned tokenizer; enforce corpus token budgets."""

import argparse
import importlib.metadata
import json
from pathlib import Path

import tiktoken


def measure(root):
    encoder = tiktoken.get_encoding("cl100k_base")
    totals = {"entry": 0, "markdown": 0}
    skills = {}
    for path in sorted((root / "plugins/10x/skills").rglob("*.md")):
        relative = path.relative_to(root / "plugins/10x/skills")
        counts = skills.setdefault(relative.parts[0], {"entry": 0, "markdown": 0})
        tokens = len(encoder.encode(path.read_text(), disallowed_special=()))
        counts["markdown"] += tokens
        totals["markdown"] += tokens
        if path.name == "SKILL.md":
            counts["entry"] += tokens
            totals["entry"] += tokens
    return {"totals": totals, "skills": skills}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--measure", action="store_true", help="Print counts without enforcing budgets")
    args = parser.parse_args()
    if importlib.metadata.version("tiktoken") != "0.12.0":
        parser.error("Install tiktoken==0.12.0 for reproducible counts")
    root = Path(__file__).resolve().parent.parent
    current = measure(root)
    print(json.dumps(current, indent=2))
    if args.measure:
        return 0
    budget = json.loads((root / "scripts/skill-token-budget.json").read_text())
    failures = []
    for surface, before in budget["baseline"]["totals"].items():
        after = current["totals"][surface]
        limit = before * 70 // 100
        print(f"{surface}: {before} -> {after} ({100 * (before - after) / before:.1f}% reduction); limit {limit}")
        if after > limit:
            failures.append(f"{surface} exceeds its 30% reduction budget")
    for failure in failures:
        print(f"FAIL: {failure}")
    return bool(failures)


if __name__ == "__main__":
    raise SystemExit(main())
