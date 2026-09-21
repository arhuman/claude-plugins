---
name: documentation-rules
description: 'Rules for writing and updating documentation. Use for any non-trivial documentation task in README.md, markdown files, text files, and code comments. Not for blog posts, essays, or newsletters: those are prose for readers, not project documentation, and this skill does not cover them.'
---

# 10x Documentation

Rules for producing clear, accurate, and maintainable documentation.

## Reference

| Resource | Purpose |
|----------|---------|
| `./references/project-artifacts.md` | The mature-project documentation set, plus CONTRIBUTING, SECURITY, AGENTS.md, CONTEXT.md, and THIRD-PARTY-NOTICES templates |

## Required Documentation Artifacts

A project intended for others (contributors or users) ships this set. When a task
touches a repo, check which are present and flag the missing ones; do not create
all of them unprompted, but name the gap.

| Artifact | Location | When required |
|----------|----------|---------------|
| README.md | repo root | always |
| LICENSE | repo root | always for anything published |
| CHANGELOG.md | repo root | once the project has releases (see Changelog) |
| CONTRIBUTING.md | repo root | once it accepts outside contributions |
| SECURITY.md | repo root | anything network-facing or handling secrets/data |
| CODE_OF_CONDUCT.md | repo root | public/community projects |
| THIRD-PARTY-NOTICES.md | repo root | when the repo vendors third-party assets or code |
| AGENTS.md (or CLAUDE.md) | repo root | any repo worked on by AI agents |
| CONTEXT.md | repo root or `docs/` | when the domain has non-obvious ubiquitous language |
| architecture.md | `docs/` | non-trivial architecture worth one overview |
| ADRs | `docs/adr/NNNN-*.md` | every architecture/format/crypto decision (see ADR section) |

mnemos is the reference for the full set. Templates for CONTRIBUTING, SECURITY,
AGENTS.md, CONTEXT.md, and THIRD-PARTY-NOTICES are in
`./references/project-artifacts.md`.

## Style: Global Rules

These apply to all output: commit messages, changelogs, READMEs, code comments, ADRs, API docs.

**Never use:**
- Em dashes (`—`). Use a comma, a colon, or rewrite the sentence.
- Emojis anywhere.
- Internal roadmap markers (phase, step, stage, part, or milestone references such as "Phase 3", "step 2", "stage 1", "Part 2") in commit messages or public documentation. Say what changed, not where it sat in a plan: a future reader has no roadmap. Exception: internal planning notes under `.claude/` may use them.
- Numbered lists unless the order is strictly required (installation steps, migration sequences). Use plain bullet lists otherwise.
- Filler phrases: "successfully", "comprehensive", "seamlessly", "leverages", "robust", "cutting-edge".
- Passive voice when active is clearer.
- Hedge words without reason: "typically", "generally", "in most cases". Say what it does.

**Always:**
- Write in the same language as the surrounding text or comments.
- Use active voice and present tense.
- Keep sentences short. One idea per sentence.
- Say what something does before explaining how.
- Write for the reader's knowledge level, not to demonstrate thoroughness.

---

## Changelog

Format: [Keep a Changelog](https://keepachangelog.com), versioned with
[Semantic Versioning](https://semver.org). State both in the file header.

Location depends on audience:
- A project intended for release keeps a public `CHANGELOG.md` at the repo root.
- The 10x scaffold's `.claude/CHANGELOG.md` (maintained by the `steering` skill) is the internal working log. At release, promote its entries to the public changelog.

Rules:
- Keep `## [Unreleased]` at the top; move it under a version heading with a date on release.
- Categories: `Added`, `Changed`, `Fixed`, `Removed`, `Security`.
- For a pre-1.0, high-churn project, nest dated entries (`### 2026-07-20`) under `[Unreleased]`.
- Cite the reason: reference the ADR or requirement ID a change implements (`See ADR 0004`).
- **Brevity is paramount: one short sentence per entry.** A public changelog lists what changed; the explanation lives in the commit and in the code and README the entry names. Mechanism, option tours, panics, edge cases and caveats never appear here.
- Changelog entries are not comments, and the Code Comments register rules do not apply to them: no glossing, plain words, drop insider vocabulary instead of defining it.
- A number belongs only with its comparison (what ran, against what, on what); when that does not fit the sentence, the number goes to the README's measurements section and the entry points there.

Good entry: `Added rate limiting middleware to the API router (see ADR 0009)`
Bad entry, padded: `Successfully implemented a comprehensive rate limiting solution that seamlessly integrates with the existing API infrastructure`
Bad entry, compressed: `Unscoped Debug costs what plain slog costs over the same Debug-open downstream (150.0 ns vs 149.2 ns)`. Three project terms in one clause and a comparison the reader cannot evaluate. Say it as: `With no scope open, dllog matches plain slog: 150.0 ns vs 149.2 ns per Debug record through the same handler (M3 Pro).`
Bad entry, over-documented: an entry that names the feature, then explains its mechanism, its panic behaviour and its sibling variants across five lines. Right change, wrong surface: keep `NewJSON and NewText build the downstream handler too, so setup is one call`, move the rest to the README.

---

## Code Comments

Default: no inline comment. Improve the name or split the function first.

The split below is by **position**, not by topic: a comment attached to an exported declaration is a doc comment, a comment inside a function body is an inline comment. They have opposite length rules. Do not apply the inline rules to doc comments.

### Inline comments (inside function bodies)

Write one only when it records something the code cannot show. These five are the **triggers**, and they are a whitelist:

1. a constraint or invariant not visible locally (units, ordering, ownership, limits);
2. a failure mode being prevented (race, leak, double close, retry storm, partial write);
3. a security or compatibility promise;
4. a lifecycle obligation on the caller (must Close, must cancel, must drain);
5. a rejected alternative, but only when the code looks like the simpler choice would work.

No trigger, no comment. Never narrate steps, restate the symbol name, or announce what the change adds.

Format: one line, two at most, naming at least one identifier from the code it sits on. Good: `// Prevent a race on handlers: they write conns concurrently.`

Needs more than two lines? Then it is not an inline comment. Move it to the doc comment of the enclosing type or function, or to an ADR referenced by number.

### Doc comments (exported symbols)

No length cap on the contract; the rationale is capped separately, below. These are **slots**, not triggers: unlike the inline list above, you are not deciding whether to write a comment, only which parts to fill. Fill the ones that apply, then stop:

- observable behavior on the nominal path;
- what this deliberately does not do, and which component does it instead;
- error contract: which error means "not mine" versus fatal, and what an error implies about state;
- constraints the types cannot express: call order, idempotency, concurrency safety, side effects;
- one short example, only when correct usage is not obvious from the signature.

A doc comment that restates the symbol name is worse than none: `// NewRouter makes a new Router` looks like documentation and carries none. Follow language conventions: GoDoc for Go, JSDoc for JavaScript, docstrings for Python.

If a comment needs a paragraph to explain **how** the code works, fix the code. A paragraph explaining **why** a subtle invariant holds belongs here.

### Rationale cap: three sentences

The contract can run as long as it must. The **why** stops at three sentences, doc comments included. One sentence for the reason, one for the constraint a reader must not break, one for the pointer. Then stop.

Past that you are writing an essay in a comment. Move it out: an ADR for a decision, a benchmark or test note for a measurement, the commit message for what changed. Four things never belong in the comment at all:

- the previous value and what it cost ("the previous 128 MiB did exactly that, costing 4x the CPU"). Git holds it, and a reader cannot act on it;
- a chain of reasoning re-derived for the reader ("X is not what bounds Y; what bounds Y is Z, because ...");
- numbers only a benchmark can confirm, with no pointer to that benchmark;
- a second pass restating the first in different words.

### Register

Write for a developer two years into the language who has never seen this codebase, does not share your context on the runtime or the incident, and is reading at 2am because something broke. They know the language well. They do not know your subsystem, your benchmark, or the discussion this decision came out of. That reader, not the reviewer who sat in the discussion with you, is the audience.

Precision is not the thing to trade away for that reader. Compression is. A comment they cannot parse protects nothing, so spend the extra sentence that makes it land and cut something else to pay for it.

Jargon is a lexical habit, not a length problem. Compressing a causal chain into one line is what produces it, which is why the cap above stops at the doc comment.

- **Gloss or drop the insider term.** "a soft limit cannot shrink a live heap" assumes GC internals. "Go cannot free memory a run is still using, so this limit never pulls the heap below that" does not.
- **Plain verbs, concrete subjects.** Not "the ceiling is a backstop on how far GOGC may then let the heap grow": say what grows, what stops it, and when.
- **One idea per sentence.** A sentence you must re-read to parse is a rewrite, not a style preference.
- **Two-term test.** Count the terms in one sentence that a reader outside this repo could not define: project nouns, mode names, states, coined adjectives. Two or more, split the sentence and define one of them. "Unscoped Debug costs what plain slog costs over the same Debug-open downstream" stacks three and states its result as a comparison the reader cannot yet evaluate. "When no scope is open, dllog adds nothing measurable" says it, then the numbers land.
- **State the outcome before the mechanism.** Lead with what happens to the reader, then how it works. "Buffered values render at flush time" makes them derive the consequence; "the replayed line shows the value as it is now, not as it was when you logged it, because dllog formats arguments only on replay" hands it to them.
- **Prefer the shorter wording whenever both are accurate.** Concision is part of the rule, not a nicety: a rationale nobody finishes reading protects nothing.
- Name concrete things: the field, the file, the goroutine, the caller. Not "the system", "the layer", "the flow".
- **Portability test.** Could this be pasted into 20 unrelated codebases unchanged? Then it says nothing about this one. Delete it.
- **Falsifiability test.** Could the comment be wrong? "Handles the user data" cannot be. "Callers must not hold mu here" can. Keep the second kind.
- Never cite an issue, incident, ADR, or commit you have not verified exists (`thinking` states the general rule). A plausible issue number is a fabrication.
- Keep comments current when code changes. A stale comment is worse than no comment.

`references/comments.md` holds the banned-vocabulary and filler-phrase lists, the concrete-subject substitution table, and worked examples of both tests. Read it when writing or reviewing a comment; it is not needed for a README or ADR edit.

---

## README and User Guides

Canonical section order for a project README:

1. Title, then a badge row (CI status, Go Report Card, latest release, license). Link each badge.
2. One-sentence positioning in bold, then a sharp "what it is not" framing so a reader places it fast.
3. Hero demo: an animated GIF, or a copy-pasteable terminal transcript that shows the tool doing its job.
4. Quickstart: a numbered, copy-pasteable, comment-annotated shell block that runs end to end (install, use, observe result). Aim for "working in 60 seconds".
5. Why / how it works: an ASCII data-flow diagram plus bullet value points.
6. Capabilities: a command or feature reference table.
7. Security, Development/Contributing, License (with a pointer to THIRD-PARTY-NOTICES if present).
8. A short Docs index near the end; push depth into `docs/` and link to it.

Techniques:
- Build the table of contents from inline anchor links (`[why](#why-x)`), not a heavy generated TOC block.
- Use `<details>` collapsibles for gotchas and edge cases so the main flow stays short.
- Put measured results (benchmarks, eval metrics) in a table, not prose.
- Keep the first screen readable without scrolling sideways; move long output into fenced blocks.

For internal/library components with no user-facing surface, a shorter README is
fine: what it does, quickstart, configuration, links.

---

## Architecture Decision Records

This section is the authoritative ADR convention for every 10x skill and agent.

- Location: `docs/adr/NNNN-slug.md`, one committed file per decision, numbered sequentially (scan `docs/adr/` for the highest number, increment by one).
- Create `docs/adr/` lazily, when the first ADR is written.
- An ADR can be a single paragraph: context, decision, why. Add `Status`, `Considered Options`, or `Consequences` only when they add real value (full rules in the grill-with-docs skill's `ADR-FORMAT.md`).
- Status values when used: `proposed` | `accepted` | `deprecated` | `superseded by ADR-NNNN`. Update a superseded ADR's status; never delete it.
- Link related ADRs when a decision builds on or contradicts a previous one.
- Do not keep a private single-file ADR log (`.claude/ADR.md` or `.claude/doc/ADR.md`): decisions belong in the repo, where future readers look.

**When an ADR is required:** anything that changes architecture, cryptography,
an on-disk or wire format, or a public contract needs one. If a reviewer would
ask "why was it done this way", write the ADR.

**Structure (Nygard):** Title, Date, Status, Context, Decision, Consequences
(positive and negative/risks), and Alternatives considered. The Alternatives
section is what stops a future reader from re-litigating a settled decision.

**Index:** maintain a `docs/adr/README.md` or `decisions.md` that lists each ADR
with its status, so the set is browsable without opening every file. Cross-link
ADRs from the CHANGELOG entry and the code (`REQ-*` / `ADR-*` references) that
implement them, so the decision, the change, and the code stay connected.

---

## API Documentation

- Use OpenAPI/Swagger annotations on every handler tied to a route.
- Document all public interfaces and methods.
- For each endpoint: request shape, response shape, authentication requirements, possible error codes.
- Include a realistic example request and response, not a placeholder.

---

## Special Annotations

When relevant, add a clearly marked note for:
- Version compatibility (which version this applies to)
- Deprecations (what replaces the deprecated feature)
- Security considerations
- Performance characteristics that affect usage decisions
