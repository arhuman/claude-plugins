---
name: documentation-rules
description: 'Rules for project documentation: README, Markdown, text files, and code comments. Not for blog posts, essays, or newsletters.'
---

# Documentation contracts

## Required Documentation Artifacts

For repos intended for contributors or users, check this set and name missing artifacts; do not create them all unprompted. mnemos is the reference project. Read [artifact contracts](references/project-artifacts.md) when authoring those files.

| Artifact | Location | Required when |
|---|---|---|
| README.md | root | always |
| LICENSE | root | published |
| CHANGELOG.md | root | releases exist |
| CONTRIBUTING.md | root | outside contributions accepted |
| SECURITY.md | root | network-facing or handling secrets/data |
| CODE_OF_CONDUCT.md | root | public/community project |
| THIRD-PARTY-NOTICES.md | root | vendored code/assets |
| AGENTS.md or CLAUDE.md | root | AI agents work here |
| CONTEXT.md | root or `docs/` | non-obvious domain language |
| architecture.md | `docs/` | non-trivial architecture |
| ADRs | `docs/adr/NNNN-*.md` | architecture, format, crypto, public-contract decisions |

## Style: Global Rules

Apply to all output, including commits, comments, API docs and changelogs:
- Match surrounding language. Use active voice, present tense, short sentences, one idea each; state what before how and match reader knowledge.
- No em/en dash punctuation, emojis, filler (successfully, comprehensive, seamlessly, leverages, robust, cutting-edge), or unjustified hedges (typically, generally, in most cases).
- No internal roadmap markers (phase, step, stage, part, milestone numbers) in commits or public docs; internal `.claude/` planning notes are exempt.
- Number lists only when order is required, such as installation or migration.

## Changelog

- Declare [Keep a Changelog](https://keepachangelog.com) and [Semantic Versioning](https://semver.org) in the header.
- Release projects use root `CHANGELOG.md`; `steering` owns the internal `.claude/CHANGELOG.md`. Promote internal entries at release.
- Keep `## [Unreleased]` on top; move entries under a dated version heading at release. Categories: Added, Changed, Fixed, Removed, Security. Pre-1.0 high-churn projects nest dates (`### 2026-07-20`) under Unreleased.
- One short sentence per entry, naming the change and its ADR/requirement reason. Put mechanisms, options, panics, edge cases and caveats in code/README/commits.
- Use plain words, drop insider terms rather than glossing them; comment-register rules do not apply.
- Numbers require a comparison naming what ran, against what, on what. If that exceeds one sentence, link the README measurements section instead.

## Code Comments

Classify by position: inside a function is inline; attached to an exported declaration is a doc comment. Never impose the inline cap on exported contracts. Read [comment vocabulary](references/comments.md) when writing/reviewing comments, not for README/ADR work.

### Inline comments (inside function bodies)

Default to none; improve names or split functions first. Write only for:
- A non-local constraint/invariant: units, ordering, ownership, limits.
- A prevented failure: race, leak, double close, retry storm, partial write.
- A security or compatibility promise.
- A caller lifecycle obligation: close, cancel, drain.
- A rejected simpler alternative that appears viable.

No trigger, no comment. Never narrate steps, repeat names, or announce additions. Use one line, at most two, naming at least one adjacent code identifier. Move longer explanations to the enclosing declaration's doc comment or an ADR referenced by number.

### Doc comments (exported symbols)

Document applicable contract slots, then stop; the contract has no length cap:
- Nominal observable behavior.
- Deliberate non-behavior and the component responsible instead.
- Errors: not-mine versus fatal, and resulting state.
- Constraints types cannot express: call order, idempotency, concurrency safety, side effects.
- One short example only if signature alone does not make usage obvious.

Do not merely restate the name. Follow GoDoc/JSDoc/docstring conventions. A paragraph explaining *how* calls for clearer code; explaining *why* an invariant holds belongs here.

### Rationale cap: three sentences

For all comments, rationale gets at most three sentences: reason, constraint, pointer. Contract length remains uncapped. Move excess to an ADR (decision), benchmark/test note (measurement), or commit (change).

Never include previous values/cost history, re-derived reasoning chains, benchmark-only claims without benchmark pointers, or a second paraphrase of the same explanation.

### Register

Sentence-level register (reader model, two-term/portability/falsifiability
tests, forbidden filler and hedges) is owned by
[senior-voice](../senior-voice/references/register.md). Read it when writing or
reviewing any comment. Comment-specific additions:

- Assume no project, runtime, or incident context, and no access to the commit
  that prompted the comment.
- Replace a comment that fails the portability or falsifiability test with a
  real constraint, or delete it.

## README and User Guides

Canonical README order:
1. Title; linked badges for CI, Go Report Card, latest release, license.
2. Bold one-sentence positioning and clear “what it is not”.
3. Hero GIF or copy-pasteable terminal demo.
4. Numbered, comment-annotated, copy-pasteable quickstart shell block: install, use, observe; target 60 seconds.
5. Why/how: ASCII data-flow diagram and value bullets.
6. Command/feature reference table.
7. Security, Development/Contributing, License; link THIRD-PARTY-NOTICES if present.
8. Short Docs index near the end; link depth in `docs/`.

Use inline-anchor TOCs, `<details>` for gotchas/edge cases, tables for measurements, fenced blocks for long output. First screen must not require horizontal scrolling. Internal/library components without a user-facing surface may use only purpose, quickstart, configuration, links.

## Architecture Decision Records

Authoritative convention for 10x skills/agents:
- One committed `docs/adr/NNNN-slug.md` per decision. Scan highest number and increment; create directory only for first ADR. No private `.claude/ADR.md` or `.claude/doc/ADR.md` log.
- Require an ADR for architecture, cryptography, disk/wire format, public-contract changes, or a decision a reviewer would ask “why” about.
- A paragraph of context, decision, why suffices. Nygard structure for expanded records: Title, Date, Status, Context, Decision, Consequences (positive and risks), Alternatives considered. Add Status/Options/Consequences only when useful; consult [ADR format](../steering/references/ADR-FORMAT.md) when writing one.
- Status, when used: `proposed`, `accepted`, `deprecated`, `superseded by ADR-NNNN`. Update superseded status, never delete records. Link decisions that build on or contradict others.
- Maintain `docs/adr/README.md` or `decisions.md` listing records and statuses; link implementing CHANGELOG entries and code with `REQ-*` / `ADR-*` references.

## API Documentation

Document every public interface/method and annotate every routed handler with OpenAPI/Swagger. Each endpoint needs request/response shapes, authentication, possible error codes, and realistic example request/response.

## Special Annotations

Clearly mark applicable versions, deprecations and replacements, security considerations, and performance characteristics affecting usage.
