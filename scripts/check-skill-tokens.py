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


def body(text):
    """Markdown after the frontmatter block: what a harness injects as prompt."""
    match = re.match(r"---\n.*?\n---\n", text, re.DOTALL)
    return text[match.end() :] if match else text


def agent_start(root):
    """Tokens each agent costs when it starts, per harness: {name: (claude_code,
    opencode, preloaded skills)}. Claude Code injects the agent prompt plus the
    body of every `skills:` entry; OpenCode injects its generated prompt."""
    encoder = tiktoken.get_encoding("cl100k_base")

    def count(text):
        return len(encoder.encode(text, disallowed_special=()))

    skills = {p.parent.name: p.read_text() for p in (root / "plugins/10x/skills").glob("*/SKILL.md")}
    generated = {p.stem: p.read_text() for p in (root / "opencode/agents").glob("*.md")}
    starts = {}
    for path in sorted((root / "plugins/10x/agents").glob("*.md")):
        text = path.read_text()
        preloaded = frontmatter_field(text, "skills").split()
        claude = count(body(text)) + sum(count(body(skills[s])) for s in preloaded if s in skills)
        opencode = count(body(generated[path.stem])) if path.stem in generated else 0
        starts[path.stem] = (claude, opencode, preloaded)
    return starts


def check_readme(root):
    """Compare the plugin README's agent-start rows with agent_start(); return
    one message per agent whose row is missing or carries other numbers."""
    rows = {}
    row = re.compile(r"^\| `([A-Za-z0-9-]+)` \| ([\d,]+) \| ([\d,]+) \|")
    for line in (root / "plugins/10x/README.md").read_text().splitlines():
        match = row.match(line)
        if match:
            rows[match.group(1)] = (int(match.group(2).replace(",", "")), int(match.group(3).replace(",", "")))
    problems = []
    for name, (claude, opencode, _) in agent_start(root).items():
        if name not in rows:
            problems.append(f"README: no agent-start row for {name} (report: {claude} / {opencode})")
        elif rows[name] != (claude, opencode):
            problems.append(
                f"README: {name} row says {rows[name][0]} / {rows[name][1]}, report says {claude} / {opencode}"
            )
    return problems


def report(root):
    """Per-harness context cost in three buckets, as text.

    catalogue: skill and agent descriptions, paid by every session.
    agent start: paid each time an agent starts. Claude Code injects the agent
    prompt plus the full body of every `skills:` entry; OpenCode injects its
    generated prompt, which only names those skills (gen-opencode.sh preamble).
    on-invoke: a skill's SKILL.md body, paid when the skill is invoked; the
    same file on both harnesses.
    """
    encoder = tiktoken.get_encoding("cl100k_base")

    def count(text):
        return len(encoder.encode(text, disallowed_special=()))

    skills = {p.parent.name: p.read_text() for p in sorted((root / "plugins/10x/skills").glob("*/SKILL.md"))}
    agents = {p.stem: p.read_text() for p in sorted((root / "plugins/10x/agents").glob("*.md"))}
    generated = {p.stem: p.read_text() for p in sorted((root / "opencode/agents").glob("*.md"))}
    starts = agent_start(root)

    skill_desc = sum(count(frontmatter_field(t, "description")) for t in skills.values())
    claude_agent_desc = sum(count(frontmatter_field(t, "description")) for t in agents.values())
    opencode_agent_desc = sum(count(frontmatter_field(t, "description")) for t in generated.values())

    lines = [
        "Context cost in cl100k_base tokens (tiktoken 0.12.0): a comparable indicator, not billing.",
        f"skills: {len(skills)}, agents: {len(agents)}",
        "",
        "catalogue (every session: skill and agent descriptions)",
        f"  claude_code  {skill_desc + claude_agent_desc:>6}  (skills {skill_desc}, agents {claude_agent_desc})",
        f"  opencode     {skill_desc + opencode_agent_desc:>6}  (skills {skill_desc}, agents {opencode_agent_desc})",
        "",
        "agent start (each time the agent starts)",
        f"  {'agent':<22}{'claude_code':>12}{'opencode':>10}  preloaded on claude_code",
    ]
    for name, (claude, opencode, preloaded) in starts.items():
        lines.append(f"  {name:<22}{claude:>12}{opencode:>10}  {' '.join(preloaded) or '-'}")
    lines += ["", "on-invoke (each time the skill is invoked, both harnesses: SKILL.md body)"]
    for name, text in skills.items():
        lines.append(f"  {name:<22}{count(body(text)):>6}")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--measure", action="store_true", help="Print counts without enforcing budgets")
    parser.add_argument(
        "--report",
        action="store_true",
        help="Print per-harness context cost: catalogue, agent start, on-invoke (measurement only, no budget)",
    )
    parser.add_argument(
        "--check-readme",
        action="store_true",
        help="Fail when the plugin README's agent-start rows differ from --report",
    )
    args = parser.parse_args()
    if importlib.metadata.version("tiktoken") != "0.12.0":
        parser.error("Install tiktoken==0.12.0 for reproducible counts")
    root = Path(__file__).resolve().parent.parent
    if args.report:
        print(report(root))
        return 0
    if args.check_readme:
        problems = check_readme(root)
        for problem in problems:
            print(f"FAIL: {problem}")
        if not problems:
            print("README agent-start table matches --report.")
        return bool(problems)
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
