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
cannot untangle overlapping paths after the fact. 10x-commit's stop rule
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

A workspace never pushes or merges into another workspace. Its 10x-commit
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

No lock server, no daemon, no auto-provisioning script, no scripted
two-session test harness. The mechanism stays prose-and-jj-native: two
commands to set up, one to clean up, and the claim protocol does the rest. A
thin helper script is worth adding only if the manual setup proves to be a
real adoption barrier.
