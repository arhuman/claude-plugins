# 10x skill-authoring standard

The contract every 10x SKILL.md follows, at creation and at every improvement pass.
It plays for skills the role standard.yml plays for repos: one written definition of
"conformant", so authoring and auditing cannot diverge. When a rule here conflicts
with an older skill's current shape, the rule wins and the skill is drifted.

Rules are numbered S1... so 10x-conform (or a manual pass) can cite them per finding.

## Universal rules (every skill)

**S1. Description = positive trigger + negative clause.** The frontmatter description
is the only always-on text; it must say when to fire AND when not to. End every
description with one anti-trigger clause naming the neighboring skill or command that
covers the excluded case ("Not for X: use Y"). Overlapping skills without negative
clauses mis-fire against each other (10x-review vs 10x-conform vs /code-review,
grill-me vs grill-with-docs).

**S2. Done-when blocks: observable exit criteria.** Every procedural phase ends with
a short "Done when" list of postconditions an agent can check, runnable commands
wherever possible (`jj log -r @ --no-graph` shows the expected header; the generated
file contains no `{{` placeholder). A rule states what to do; a Done-when states how
the skill knows it happened. Prose like "confirm it worked" inside a bullet does not
count: the check must be closed, listed, and mechanically evaluable. Self-report is
never the gate.

**S3. One fact, one home.** A value, threshold, version, or rule lives in exactly one
file; every other mention points there. A duplicate keeps its home and loses the copy.
Cross-skill facts go to `_shared/references/` (versions.md, standard.yml, this file).

**S4. Dense single file below ~250 lines; split by phase above.** The 10x voice is
self-contained argued prose, and it survives lazy loading better than thin routers
that beg the model to read sub-files. Keep one SKILL.md until it outgrows ~250 lines;
then move phase-specific procedure into references/ loaded when that phase runs, and
keep in SKILL.md only the trigger, the invariants, and the phase map. Never split a
single-pass skill: that is ceremony, not structure.

**S5. Self-policing templates.** Any template or asset a skill fills ends with an
instruction to fill every placeholder and delete the instruction line, and the
skill's Done-when includes the leak check (no `<...>` or `{{...}}` left in the
written file).

## Conditional patterns (adopt when the skill matches the shape)

**S6. Trust gate (skills that grade or score).** Before emitting scores, the model
answers internally: am I confident in every consequential judgment here; would the
user be satisfied with the real end-to-end outcome. A "no" forces the doubt to
surface as a mandatory finding and caps the confidence statement; a doubt that
leaves no trace in the report is a rule violation. Pair with a closed section list:
the report may not add, rename, or reorder sections, and a pass that did not run is
marked "Not run", never filled with invented findings.

**S7. Cheapest-first verification cascade (skills that look up or verify facts).**
Resolve claims in cost order: project memory and docs first (free), then the
codebase (free), then the web (metered). Stop at the first authoritative resolution;
route by claim category instead of running every tier. An unverified claim is never
deleted and never asserted as fact.

## Wording bank

Formulations proven sharper than their generic equivalents. Reuse verbatim or adapt;
each earns its place by forcing a behavior a softer phrasing loses. Every line below
is integrated where noted (2026-08-29); the bank stays the quotable home for reuse
in new skills, and a new skill matching a line's shape should carry it.

- "Ask only questions that can change what gets built." (integrated: grill-with-docs)
- "Stop when remaining gaps are explicit assumptions, not hidden ambiguity." (integrated: grill-with-docs Done when)
- "A bare opinion is not a finding: tie each to a checklist item, a threshold row, a duplication site, or a confirmed defect." (integrated: 10x-review Severity rules)
- "Never record a finding inferred from naming alone: a plausible name is not evidence." (integrated: 10x-review Severity rules; kin to 10x-thinker phantom references)
- "Unscannable check: mark it Not run with the reason, never invent findings for it." (integrated: 10x-review closed sections and 10x-conform MUST NOT, via S6)
- "Never trust a delegate's claim alone: verify with a concrete check." (integrated: coder-agent Delegation)
- "Honesty over escape: never report done until the success condition genuinely passes." (integrated: coder-agent Workflow)
- "No silent TODO, skipped test, or placeholder mock: declare anything you bypass." (integrated: coder-agent and fixer-agent)
- "empty, duplicate, concurrent, stale, missing, hostile, partial" (integrated: 10x-tester MUST DO)
- "Use premortem for risk: shipped, failed, why?" (integrated: grill-with-docs)
- "Code silent on a line is not code that contradicts it." (integrated: 10x-plan init)
- "Points to the code over a copy. Names a tech without its version." (integrated: 10x-plan init)
- "A hook that rejects the commit is not this skill's job: report which hook and why, then stop." (integrated: 10x-commit MUST DO)

## Applying this standard to an existing skill

An improvement pass over a skill checks, in order: description has its negative
clause (S1); every phase has a Done-when (S2); no fact duplicated from a _shared
reference or another skill (S3); line count vs the split threshold (S4); templates
self-police (S5); then S6/S7 if the skill grades or verifies. Fix what fails, cite
the rule id in the commit message, and leave the rest untouched.
