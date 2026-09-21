# Chaining (`--chain N`)

Explicit `--chain N` permits at most N phases. Run SKILL.md steps 0-6 in full for each.

- Stop at N or the first gate failure, `blocked` phase, or phase with unverified dependencies. Never skip red to advance the chain.
- One phase, one commit: no squash or combined message.
- Persist the plan after each phase, so interruption leaves single-turn-equivalent state.
- Final report lists every closed phase with its quoted evidence, not only the last.

Done only when the bound/first non-green stop, per-phase commits, evidence and durable plan state all hold.
