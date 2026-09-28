# Concurrency: jj workspaces and plan-file claims

Two independent mechanisms cover two independent failure modes:

- The claim protocol (`plan-format.md`, Claiming a phase) stops two sessions
  from implementing the same phase.
- jj workspace isolation, this file, stops two sessions from corrupting each
  other's working-copy state even when they correctly work on different
  phases.

Neither substitutes for the other. A correctly claimed phase implemented in a
shared checkout still races: in jj the working copy `@` is a real commit, one
per workspace, and by default a repo has exactly one workspace. Two sessions
in the same directory share one `@`, so their edits land in the same
uncommitted change, indistinguishable once both have written, and `jj split`
cannot untangle overlapping paths after the fact. commit's stop rule
("changes you did not make this session") is the safety net for that
situation, not a substitute for avoiding it.

## Setup, once per concurrent session

```
jj workspace add ../<repo>-<slug>
cd ../<repo>-<slug>
```

The workspace lives in a sibling directory named for the session or phase it
serves (`repo-loop-p7/`), never nested inside the main checkout: nesting
defeats the isolation and confuses tools that walk the tree for `.jj`. Each
workspace has its own `@`; all workspaces share one underlying repo, so
commits, bookmarks, and files at unchanged paths are the same everywhere.

Secondary workspaces are jj-only even when the main checkout is colocated:
run git-side inspection (`git log`, `git status`) from the main workspace,
and everything else through `jj`.

## Landing work

A workspace never pushes or merges into another workspace. Its commit
step lands the commit in the shared repo, immediately visible from every
other workspace via `jj log`, with no sync step. What remains shared and
mutable is exactly two things:

- **The plan file**: one file, same content from every workspace once
  committed state converges; the claim protocol covers it entirely. A plan
  under `.claude/` is per-checkout (gitignored), so concurrent sessions
  driving one plan should run against one plan file, reached via the main
  checkout's path, or accept that each workspace sees its own copy.
- **`CHANGELOG.md` `[Unreleased]`**: two sessions each appending an entry in
  their own commit produce sibling commits; rebasing one onto the other can
  conflict on the inserted lines. That is an ordinary two-line-insert
  conflict: resolve by keeping both entries, never by dropping one. No
  special tooling.

## Cleanup

```
jj workspace forget <name>
```

Forget removes the repo's record of the workspace, not the directory; delete
the directory separately. A forgotten workspace's landed commits are
unaffected.

## What this deliberately does not add

No lock server, no daemon, no auto-provisioning script. The mechanism stays
prose-and-jj-native: two commands to set up, one to clean up, and the claim
protocol does the rest. A thin helper script is worth adding only if the
manual setup proves to be a real adoption barrier. `scripts/test-claim.sh`
(P21) is not that kind of script: it proves the mutex/token protocol itself
against a toy plan, sequentially, which exercises the same compare-and-swap
code path as a genuine race (`mkdir` is atomic; a backgrounded two-process
race was checked by hand while writing it and confirmed the same
exactly-one-wins result) without the flakiness of timing two real processes
in CI.

## What differs under OpenCode (checked 2026-09-28, P21)

A two-phase toy plan (`.claude/plan/toy.md`) in a scratch project, driven by
`opencode run --dir <toy> --command 10x-loop`:

- **`.claude/plan/` is reachable.** It is a plain directory; nothing in
  either harness treats `.claude/` specially. `opencode run --dir` resolves
  paths relative to the given directory the same way Claude Code resolves
  them relative to its working directory, so plan resolution itself needs no
  harness-specific handling.
- **The session id has no harness-provided source, under either harness.**
  `loop/SKILL.md` referenced `"$SESSION"` as if it were an environment
  variable; neither Claude Code nor OpenCode exposes one to the model. Fixed
  in this phase: the skill now says to construct one (`loop-$(date +%s)`)
  rather than read one that does not exist. This was not an OpenCode-only
  gap, it was a doc gap latent under both harnesses; running the loop for
  real under OpenCode is what surfaced it, because a fresh session with no
  prior convention has nothing to imitate.
- **Which step the OpenCode agent could not perform: none, mechanically.**
  The loop got no further than model dispatch: this installation's bound
  models (`opencode.json`, from `scripts/opencode-models.json` and the local
  `10x-models.json` override) resolved to a provider id the account could not
  reach (`Insufficient account funds` on the first model that did resolve;
  the agent's own default tier resolved to a stale id, `openai/gpt-5.5:latest`,
  that does not match the override file's `openai/gpt-5.6-*` tiers at all,
  itself worth a look outside this phase). No loop step, hook, or claim
  operation failed; the run never reached a point where any of those would
  execute. Recorded here rather than fixed, since it is a local account/model
  binding issue, not a defect in `claim.sh`, `loop/SKILL.md`, or the install
  path, and this phase's Steps say to fix only `claim.sh` and session-id
  issues, everything else becomes a new phase.
- One incidental environment note, not a 10x defect: a plain shell `cd` into
  a scratch directory outside this repo did not persist across tool calls in
  this session (the harness resets its cwd), which is why the OpenCode run
  above used `opencode run --dir` explicitly rather than relying on a prior
  `cd`. Worth knowing if a future loop turn needs to drive OpenCode from a
  scratch checkout.
