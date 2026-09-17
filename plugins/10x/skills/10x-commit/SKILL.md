---
name: 10x-commit
description: 'jj (Jujutsu) commit mechanics: scoping, message composition, and push, hardened against the specific failures that keep recurring - a message body line starting with "-" getting misparsed, jj push failing on a missing or untracked bookmark, commitlint header/body length rejections, unrelated changes squashed into one commit, and a pushed commit being amended or squashed into (rewriting public history). Use whenever creating, describing, or pushing a jj (or jj-colocated git) commit, and before any squash/amend/split/abandon of an existing revision. Not for auditing a repo''s commit conventions or standard drift: that is 10x-conform.'
---

# 10x Commit

Version control mechanics are a deterministic protocol problem, not a judgment
call: treat commit creation as a fixed pipeline, not a one-shot `jj describe`.
Skipping a step is exactly what produces the failures below.

## MUST DO

- Run `jj status` (and `jj diff --stat` for a multi-file change) before describing anything. Enumerate every logical change. If more than one unrelated feature or fix is present, `jj split` them apart first - never bundle unrelated work into one commit because splitting felt like overhead. Always pass the filesets explicitly (`jj split <paths>`): bare `jj split` opens the diff editor and then prompts for a description per commit, which hangs a non-interactive session rather than failing.
- If `jj status` shows changes you did not make this session, stop and report them rather than splitting or describing them. `jj split` puts exactly the paths you name in the selected commit, so a path list assembled from a working copy someone else also wrote to silently commits their uncommitted work.
- Look for the target repo's own commit rules before assuming defaults: `.commitlintrc*`, `commitlint.config.*`, a `commitlint` key in `package.json`, or a local `commit-msg` hook. Some shells also wrap the `jj` command itself to lint `-m` messages before letting them through (`type jj` reveals this) - useful as a second check, but not guaranteed to exist on every machine, so still apply the rules below yourself.
- Absent a repo-specific config, default to Conventional Commits (`type(scope): subject`) with a header <=72 characters and body lines <=100 characters - the convention this plugin's own `10x-documentation` skill documents for a project's CONTRIBUTING.md. That reference is a template for a scaffolded repo's own convention; the numbers here are this skill's authoring fallback, deliberately independent facts even while the values match.
- Compose the full message (header + body) first, verify header and body-line lengths against whichever limits apply, *then* pass it to `jj describe` - not the reverse.
- Never hand a message whose body can start with `-` to `jj describe -m` as an interpolated argv string. Use `jj describe --stdin` piped from a quoted heredoc instead (`jj describe --stdin <<'EOF' ... EOF`): stdin content is never argv-parsed, so a leading `-` on any body line cannot be misread as a flag.
- Before `jj git push`, confirm a bookmark exists and points at the change (`jj bookmark list`); create and track one explicitly (`jj bookmark create <name>`, `jj bookmark track <name>@<remote>`) rather than pushing and reacting to a missing/untracked-bookmark error after the fact.
- In a script under `set -o pipefail`, capture jj output into a variable before matching it (`out=$(jj bookmark list 2>/dev/null || true)`, then `grep -q ... <<<"$out"`). Never pipe jj straight into `grep -q`: grep exits on its first match, jj dies on the broken pipe with exit 3, and pipefail promotes that 3 to the pipeline status, so a bookmark that exists reads as missing. The bug only shows once the match is not the last line printed, which is why it survives every early test.
- If the repo tracks a `CHANGELOG.md` at its root (`git ls-files --error-unmatch CHANGELOG.md` succeeds), a `feat`, `fix` or `perf` commit must carry its entry under `[Unreleased]` *in the same commit*: write the entry (dated group, Keep a Changelog style, public-facing: what changed, not why) before describing. A local-only `.claude/CHANGELOG.md` entry does not satisfy this; the tracked file is what release tooling promotes into release notes. Skip only when the change is genuinely invisible to users and say so in the commit body.
- A hook that still rejects the commit after the compose-step checks passed is not this skill's job to fix: report which hook fired and why, then stop. Re-stage only files a hook auto-formatted; never loop describe-fail-tweak until the hook goes quiet.
- After describing, run `jj status` to confirm the commit is non-empty and scoped to what you intended, before reporting it as done.
- Close the pipeline with `jj new` whenever any further work may follow in the session. In jj the described commit stays the working copy, and the next edit amends it silently: this is exactly how two units of work fuse into one commit and cost a `jj split` later. The colocated-git section's clean-`git status` note is a second reason for the same command, not the only one.
- Keep the body optional and terse: if the header already says it, write no body; when a body helps, list bullets (`*`, not `-`), one per change, not narrative prose.
- Treat every pushed commit as immutable. Before `jj squash`, `jj describe`, `jj split` or `jj abandon` on any revision other than `@`, confirm it is unpushed: `jj log -r 'remote_bookmarks()..<rev>'` must list it, i.e. the revision is not an ancestor of any remote bookmark. If it *is* on a remote, the only correct move is a new commit on top - amending it rewrites history other clones have already fetched.
- Fix a pushed mistake forward: a new commit (`fix:`, `ci:`, `revert:` as fits) stacked on the branch, never an amend plus force-push. A red CI mark on a superseded commit is an accurate record, and keeping it costs nothing next to breaking every fetched clone.
- Run the repo's full pre-push gate before the first push, not the quick subset: whatever CI actually runs (`make audit`/`make ci` in a 10x repo), so the fix-forward commit is not needed in the first place. Pushing on `make test` alone is what turns one clean commit into a broken commit plus a repair.

## MUST NOT

- Describe a commit before running `jj status`/`jj diff` to confirm its scope.
- Pass a message whose body can start with `-` through `jj describe -m "<string>"`; use `--stdin` instead.
- Run `jj git push` without first confirming the bookmark is created and tracked.
- Squash unrelated changes into one commit because splitting felt like overhead.
- Run `jj split` without naming filesets, or any other jj command that drops into the diff editor: an interactive prompt in a non-interactive session hangs until the turn is killed, and nothing in the output says so.
- Describe or split a working copy containing changes this session did not make.
- Describe a `feat`/`fix`/`perf` commit without its `CHANGELOG.md` entry when the repo tracks one at the root; an empty `[Unreleased]` discovered at release time is the failure this prevents.
- Assume the 72/100 fallback applies to a repo that ships its own `.commitlintrc`/hook - that repo's config wins.
- Report a commit as done without having verified (`jj status`) that it is non-empty and in the intended repo.
- Leave a described `@` as the working copy when more work follows: the next edit amends it, and two unrelated changes fuse without any command saying so.
- **Modify a commit that has been pushed.** No `jj squash --into`, `jj describe`, `jj split` or `jj abandon` on a revision reachable from a remote bookmark, and no `jj git push --allow-backwards`/`git push --force` to make one land. This holds even when the pushed commit is broken, even when the fix is one line, and even when the history would read more tidily squashed - tidiness is not worth invalidating every clone that already fetched it.
- Offer squashing or amending a pushed commit as an option "if nobody has pulled yet". Whether anyone pulled is unknowable from inside the repo, so the caveat is not a safeguard; do not raise it.
- Push before the repo's own full gate has passed locally.

## Done when

- `jj log -r @ --no-graph -T description` prints a header and body that pass whichever limits applied in the compose step (repo config, else the 72/100 fallback), and no body line starts with `-`.
- `jj diff -r @ --stat` is non-empty and lists only the files of the one logical change being committed.
- For a `feat`/`fix`/`perf` commit in a repo where `git ls-files --error-unmatch CHANGELOG.md` succeeds: that same `jj diff -r @ --stat` includes `CHANGELOG.md`, or the commit body states why the change is user-invisible.
- Before any push: `jj bookmark list` shows the bookmark pointing at the change and tracked at the remote.
- If pushed: `jj git push` exited 0 and named the moved bookmark; no missing- or untracked-bookmark error was retried into silence.
- Every revision this session rewrote was unpushed at the time: `jj log -r 'remote_bookmarks()..<rev>'` listed it before the rewrite. No push used `--allow-backwards` or `--force`.
- The push moved the bookmark strictly forward: the `jj git push` output reads `Move forward bookmark <name> from <old> to <new>`, not `Move sideways`/`Move backward`.

## Colocated git repos

A `jj git init --colocate` repo keeps `.git` alongside `.jj`. `git log`, `git
diff`, and `git status` are fine for inspection, but create the commit through
`jj` (`jj describe`, `jj new`), never `git commit`, so jj's own change tracking
stays consistent with what git sees.

Git HEAD sits at the working copy's *parent*, so the files of the `@` commit
show up as uncommitted changes to git. Any tool that gates on a clean
`git status --porcelain` (release scripts, pre-flight checks, CI helpers) will
therefore refuse to run right after a `jj describe`, even though the work is
committed. Run `jj new` first: it opens an empty working copy, advances git HEAD
onto the described commit, and the tree reads clean. Reporting such a tool as
"broken" before checking this is the recurring mistake.
