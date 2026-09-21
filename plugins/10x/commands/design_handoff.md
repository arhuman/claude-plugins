---
description: 'Assemble the ready-to-paste design brief for an external generator (a fresh Claude session, a design agent, an artifact builder): the fixed directive from the design-system skill with the three PROJECT blocks filled from the target repo. With --check, gate a returned deliverable instead. Never runs the generation itself.'
argument-hint: "[screen ...] | --check <css-dir>"
disable-model-invocation: true
---

## Usage
`/design_handoff`                    brief for the whole project (all screens in docs/ux.md)
`/design_handoff <screen> ...`       brief scoped to the named screens
`/design_handoff --check <css-dir>`  gate a returned deliverable (audit + dialect diff + placement)

Not `/handoff`: that command saves or restores an interrupted phase. This one delegates design work outward and gates what comes back.

## Context
- Arguments: $ARGUMENTS
- Protocol and directive (source of truth): `skills/design-system/references/design-handoff.md`
- Return gate runner: `skills/design-system/references/audit-ui.sh`
- Canonical vocabulary the dialect diff checks against: `skills/design-system/references/css-contract.md`

## Workflow

### Brief mode (default)

1. Load the `design-system` skill and read `design-handoff.md`.
2. Gather the three PROJECT blocks from the target repo:
   - TOKENS: the project's `tokens.css` (or the `:root` and theme scopes of a mono-file). Missing: leave the block empty; the directive already tells the generator to propose values flagged as proposals.
   - SCREENS: the rows of `docs/ux.md` for the screens in `$ARGUMENTS`, or all rows when no screen is named. A named screen with no row is reported, not invented: the screen is not designed yet, and the brief must say so.
   - COMPONENTS: the component registry from `docs/ux.md`, else `ls <css-dir>/blocks/`, else the block classes greppable from the mono-file.
3. Assemble the brief: the directive between the two `---` markers of `design-handoff.md`, **copied verbatim**, with only the three PROJECT blocks filled. Never reword the fixed part: every paraphrase so far has dropped the constraint that mattered.
4. Write it to `.claude/doc/design-brief-<scope>.md` and print it in full, ready to paste.
5. Close with the return instruction: run `/design_handoff --check <css-dir>` on the deliverable.

### Check mode (--check)

1. Run `sh skills/design-system/references/audit-ui.sh all <css-dir>` and quote the output. Any FAIL: the deliverable goes back with the audit output, not prose feedback.
2. Diff the deliverable's token names against the canonical vocabulary in `css-contract.md`: a parallel dialect (`--color-bg` next to `--bg-base`) is a rejection even when the audit passes.
3. Verify placement: new blocks are files under `blocks/`, never appended to an existing one; `docs/ux.md` gained a row per new screen (`verify-ux.sh` confirms).
4. Verdict: ACCEPT, or BOUNCE with the exact failing output attached.

## Constraints
- Never run the design generation itself; this command prepares the outbound brief and gates the inbound result, nothing between.
- The fixed directive is copied verbatim from `design-handoff.md`, never paraphrased or trimmed. Only the three PROJECT blocks vary.
- Only writes under `.claude/doc/`; the target repo is untouched in both modes.
- The generator is untrusted by construction: acceptance depends only on the check-mode gate, never on the brief having been read.
- A returned deliverable is judged by scripts where a script exists; the quality grid (4/4/4, dominant action named) is quoted from the generator's own declaration and verified by reading the screen, but it warns, it does not block: only the audit and the verifiers produce exit codes.
