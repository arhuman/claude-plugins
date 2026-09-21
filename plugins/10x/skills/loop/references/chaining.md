# Chaining (`--chain N`)

Loaded when `--chain N` is passed. The core loop turn (SKILL.md steps 0-6)
is unchanged and runs in full on every phase; this file only adds the
multi-phase wrapping behavior around it.

`--chain N` allows up to N phases in one run. It exists because a run of
mechanical phases costs one prompt each for no judgment in between, and that is
real friction. It stays opt-in and bounded because the one-phase default is what
keeps a rollback cheap.

The gate is unchanged and runs in full on every phase. What changes is only what
happens after a green one.

- **Stop on the first failure.** A gate failure, a `blocked` phase, or a phase whose dependencies are not `verified` ends the chain there. Never move to phase N+1 to "make progress" while N is red: two failures on two different phases is a run nobody can unwind.
- **One phase is still one commit.** Chaining changes the number of turns, never the granularity of history. No squashing, no combined message.
- **Report every phase, with its evidence.** The final report lists the N phases and the quoted output that closed each one, not just the last. A chain whose middle is unproven is a chain that proved nothing.
- **The plan file is written after each phase**, not once at the end. An interrupted chain must leave the same state a sequence of single turns would have left.

**Done when:** the chain stopped at N phases or at the first non-green one,
whichever came first; each closed phase has its own commit and its own quoted
evidence; the plan file reflects every phase closed, not only the last.
