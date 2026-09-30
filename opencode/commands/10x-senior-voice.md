---
description: 'Rewrite an existing report, finding, or document in the senior-voice register without changing its diagnosis, evidence, severity, or confidence. For review findings, preserves the existing report shape and technical detail while making behavior and consequence clear. Not for producing a new graded review.'
---

## Usage
`/10x:senior-voice <PATH>`

## Description
Rewrites a deliverable a reader did not understand. Applies the `senior-voice`
register while preserving the document's purpose and required format.

This is a rewrite, not a re-review. No finding is added, removed, rescored, or
re-evidenced.

## Context
- Target: $ARGUMENTS
- Files can be referenced with @ syntax. With no argument, use the deliverable most recently written in this session, and name it before rewriting.

## Workflow

1. Load the `senior-voice` skill, plus `references/jargon.md` and `references/register.md`.
2. Read the target in full. Classify it: graded review report, single finding, README or guide, CHANGELOG, or other reader-facing prose.
3. For a report or findings, identify each entry's severity and structure from the existing text. Do not infer or change severity.
4. Preserve the existing entry shape unless the user asks for a new one. Keep every mechanism, identifier, metric, and `file:line` needed to verify the claim.
5. Rewrite within that shape using behavior before mechanism and consequence before abstract category. Do not drop technical content merely because it is dense.
6. Preserve every existing agent prompt. Improve its wording only when needed, without inventing files, constraints, fixes, or verification commands.
7. Rewrite score rationales and synthesis prose to state concrete consequences while keeping axis names and scores unchanged.
8. Run the skill's completion check. Report missing evidence or context instead of inventing it.

## Output

Write the rewrite next to the original as `<name>-plain.<ext>`, leaving the
original untouched, unless the user asks for an in-place edit.

Close with: entries rewritten, claims that lacked enough context to rewrite
safely, and any wording whose confidence or consequence conflicted with the
underlying evidence.
