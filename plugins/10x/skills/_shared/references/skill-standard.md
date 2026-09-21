# 10x skill-authoring standard

Conformant skills are compact behavioral contracts for AI agents, not tutorials
for humans. Keep text only when it changes a decision, constrains an action,
defines an output, or verifies completion. If this file conflicts with an older
skill, this file wins and the skill is drifted.

Rules are numbered S1... so conform or a manual pass can cite findings.

## Universal rules (every skill)

**S1. Trigger contract.** The frontmatter description is the always-loaded
router. It states positive triggers and ends with one anti-trigger naming the
neighboring skill or command.

**S2. Behavioral density.** Each sentence must change a decision, action,
output, or check. Delete tutorials, personas, rationale, and example catalogs
unless they encode a project-specific constraint or disambiguate an exact
format.

**S3. Observable gates.** Every phase that can finish has completion criteria
with runnable or inspectable checks. Self-report is not a gate. Unknown or
unrun work is reported as such, never filled with invented success.

**S4. One fact, one home.** A value, threshold, version, template, or rule has
one owner. Other skills point to that owner and state when to load it. Moving
text into a reference does not count as reduction.

**S5. Reference loading.** `SKILL.md` keeps triggers, invariants, phase map,
stop conditions, and required evidence. References hold phase detail, templates,
or long local contracts, and each reference link says when it must be read.

**S6. Self-policing templates.** Any template or asset a skill fills instructs
the agent to fill every placeholder and delete the instruction. Completion
checks include no leaked `<...>` or `{{...}}` placeholders.

**S7. Token budget.** Skill entry points and total skill Markdown must stay
within `scripts/skill-token-budget.json` via `scripts/check-skill-tokens.py`.

## Conditional patterns (adopt when the skill matches the shape)

**S8. Trust gate.** Skills that grade or score surface consequential doubt as a
finding or `Not run`; closed reports cannot add, rename, or reorder sections.

**S9. Verification order.** Skills that resolve facts check project memory/docs,
then code, then metered web sources. Stop at the first authoritative source; an
unverified claim is never deleted or asserted as fact.

## Applying this standard to an existing skill

An improvement pass checks S1 through S7 for every skill, then S8/S9 when the
skill grades or verifies. Account for each requirement as retained,
consolidated, or removed with reason. Fix only drift in scope.
