---
name: commit
description: 'jj commit protocol: scope, split, message composition, hooks, bookmarks and push without rewriting published history. Use when creating/describing/pushing a jj or colocated-git commit, and before squash/amend/split/abandon. For auditing commit conventions or standard drift, use conform.'
---

# 10x Commit

Follow this pipeline, not a one-shot `jj describe`.

## MUST DO

1. **Scope.** Run `jj status` and, for multi-file work, `jj diff --stat` in the intended repo. Enumerate logical changes. If any changes were not made this session, stop and report; do not split or describe them. Concurrent sessions must first load `../_shared/references/concurrency.md` and use separate jj workspaces.
2. **Separate.** Split unrelated features/fixes before describing, always with explicit filesets: `jj split <paths>`. Never invoke bare split or another command that opens an interactive diff editor.
3. **Protect history before rewriting.** Pushed commits are immutable, including a pushed `@`. Before squash/describe/split/abandon of a revision other than `@`, confirm `jj log -r 'remote_bookmarks()..<rev>'` lists it: it must not be an ancestor of any remote bookmark. Fix pushed mistakes with a new `fix:`, `ci:` or `revert:` commit on top.
4. **Resolve message rules.** Inspect `.commitlintrc*`, `commitlint.config.*`, `package.json`'s `commitlint`, and local `commit-msg` hooks. `type jj` reveals shell lint wrappers, but never rely on one existing. Repo rules win; absent configuration, use Conventional Commits `type(scope): subject`, header <=72 characters, body lines <=100. These fallback limits are independent of the scaffold's `documentation-rules` template.
5. **Changelog before describe.** If `git ls-files --error-unmatch CHANGELOG.md` succeeds, `feat`/`fix`/`perf` must include a root `CHANGELOG.md` entry in the same commit: `[Unreleased]`, dated group, Keep a Changelog, public-facing what changed. Private `.claude/CHANGELOG.md` does not count. Skip only for genuinely user-invisible work and explain in the commit body.
6. **Compose and validate first.** Build the full message, check applicable lengths, then describe. Body optional: omit when the header suffices; otherwise terse `*` bullets, one change each, no narrative or leading `-` lines. Use a quoted heredoc through `jj describe --stdin <<'EOF' ... EOF`; never interpolate a potentially dash-leading body into `-m` argv.
7. **Hook stop.** If a hook rejects after compose checks, report the hook and reason, then stop. Re-stage only files the hook auto-formatted. Never repeat describe/fail/tweak until quiet.
8. **Verify and close.** Run `jj status` after describing: non-empty, intended repo and scope. Perform Done-when checks on the described revision before `jj new`. Whenever further work may follow, finish with `jj new` so edits cannot silently amend this commit.
9. **Before a requested push.** Run the full gate CI uses (`make audit`/`make ci` in 10x), not `make test` alone. Confirm `jj bookmark list` points at the change and tracks the remote; create/track explicitly if needed (`jj bookmark create <name>`, `jj bookmark track <name>@<remote>`). Do not push first and retry missing/untracked errors.

Under `set -o pipefail`, capture jj output before matching:

```sh
out=$(jj bookmark list 2>/dev/null || true)
grep -q ... <<<"$out"
```

Never pipe jj into `grep -q`: early grep exit can give jj broken-pipe exit 3 and falsely report a missing bookmark.

## MUST NOT

- Bypass scope, authorship, explicit-fileset, changelog, message or hook gates above.
- Modify any revision reachable from a remote bookmark, even for a one-line fix or cleaner history. Never offer "if nobody pulled" as an exception; that is unknowable.
- Use `jj git push --allow-backwards` or `git push --force`. Fix published mistakes forward; a red historical CI result is not permission to rewrite.
- Push before the full local gate, or leave described `@` open when work may follow.

## Done when

Before opening the fresh change:

- `jj log -r @ --no-graph -T description` passes repo limits (else 72/100); no body line starts with `-`.
- `jj diff -r @ --stat` is non-empty and contains only the intended logical change; `jj status` confirms intended repo/scope.
- A tracked root changelog accompanies `feat`/`fix`/`perf`, or the body explains user invisibility.
- Each rewritten revision was unpushed, with the required `remote_bookmarks()..<rev>` check before rewriting.

For a push: bookmark pointed at the change and was tracked beforehand; full gate passed; `jj git push` exited 0 and named the moved bookmark without retrying bookmark errors into silence. Movement must be strictly forward (`Move forward bookmark <name> from <old> to <new>`), never sideways/backward; no force/backwards flags.

## Colocated git repos

In `jj git init --colocate` repos, git log/diff/status are inspection tools; create commits through jj, never `git commit`. Git HEAD is `@`'s parent, so described files still appear uncommitted to git. Before declaring clean-tree-gated release/preflight/CI tools broken, run `jj new`: the empty working copy moves git HEAD to the described commit and makes git status clean.
