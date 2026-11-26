# Chaining (`--chain N` or `--chain all`)

Explicit `--chain N` permits at most N phases. `--chain all` runs every eligible `todo` phase, including phases recorded during the run.

A phase recorded during the run joins the chain when all of these hold: it was recorded in the same plan, its dependencies are `verified`, its Scope stays inside paths the plan's phases already touch, and its body states no test-contract change (an assertion or expected value to change, or a test to delete). Otherwise it stays `todo` and the final report lists it for the user. Under `--chain N`, recorded phases count toward N.

Each phase runs in a fresh general-purpose subagent, so the chain replaces the manual context clear between turns. The parent never implements a phase itself. Give each subagent the resolved plan path and phase id, and tell it to load `loop` and run exactly one turn (steps 0-6) for that phase, then report the change-id, final status and quoted gate output.

Subagent reports are not evidence. Before chaining the next phase, the parent checks on disk: the plan entry is `verified` with the reported change-id, `jj log -r <change-id>` shows that commit, `@` is empty and undescribed, and the phase's acceptance command, rerun by the parent, exits 0 (quote it). Any mismatch stops the chain.

- Stop at N or the first gate failure, `blocked` phase, or phase with unverified dependencies. Never skip red to advance the chain. Exception: a phase blocked by a restoring phase step 4 just recorded continues the chain with that phase, then with the unblocked one; both count toward N, including under `--chain all`.
- One phase, one commit: no squash or combined message.
- Persist the plan after each phase, so interruption leaves single-turn-equivalent state.
- Final report lists every closed phase with its quoted evidence, not only the last.

Done only when the bound/first non-green stop, per-phase commits, parent-rerun acceptance, evidence and durable plan state all hold.
