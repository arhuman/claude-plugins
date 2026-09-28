#!/usr/bin/env python3
"""Measure skill Markdown with a pinned tokenizer; enforce corpus token budgets."""

import argparse
import importlib.metadata
import json
import re
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


def frontmatter_field(text, key):
    """Read one top-level `key: value` line from a Markdown frontmatter block."""
    in_frontmatter = False
    for line in text.splitlines():
        if line.strip() == "---":
            if in_frontmatter:
                break
            in_frontmatter = True
            continue
        if in_frontmatter and line.startswith(f"{key}:"):
            return line[len(key) + 1 :].strip().strip("'\"")
    return ""


def report(root):
    """Per-harness always-loaded context: skill descriptions (both harnesses)
    plus, on OpenCode, the generated 'Read these skills first' preamble every
    agent declaring `skills:` carries (gen-opencode.sh, rewrite step)."""
    encoder = tiktoken.get_encoding("cl100k_base")
    skills_dir = root / "plugins/10x/skills"
    description_tokens = 0
    per_skill = {}
    for skill_md in sorted(skills_dir.glob("*/SKILL.md")):
        name = skill_md.parent.name
        desc = frontmatter_field(skill_md.read_text(), "description")
        tokens = len(encoder.encode(desc, disallowed_special=()))
        per_skill[name] = tokens
        description_tokens += tokens

    preamble_tokens = 0
    per_agent_preamble = {}
    for agent_md in sorted((root / "plugins/10x/agents").glob("*.md")):
        skills_line = frontmatter_field(agent_md.read_text(), "skills")
        if not skills_line:
            continue
        names = re.sub(r"\s+", ", ", skills_line.strip())
        preamble = f"Read these skills first: {names}."
        tokens = len(encoder.encode(preamble, disallowed_special=()))
        per_agent_preamble[agent_md.stem] = tokens
        preamble_tokens += tokens

    return {
        "claude_code": {
            "always_loaded": description_tokens,
            "skill_descriptions": per_skill,
        },
        "opencode": {
            "always_loaded": description_tokens + preamble_tokens,
            "skill_descriptions": per_skill,
            "agent_preambles": per_agent_preamble,
        },
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--measure", action="store_true", help="Print counts without enforcing budgets")
    parser.add_argument(
        "--report",
        action="store_true",
        help="Print per-harness always-loaded context cost (measurement only, no budget)",
    )
    args = parser.parse_args()
    if importlib.metadata.version("tiktoken") != "0.12.0":
        parser.error("Install tiktoken==0.12.0 for reproducible counts")
    root = Path(__file__).resolve().parent.parent
    if args.report:
        print(json.dumps(report(root), indent=2))
        return 0
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
