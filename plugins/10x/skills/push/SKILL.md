---
name: push
description: 'jj push protocol: audit every outgoing commit, not just this session''s, for message rules jj never hook-checks, agent attribution trailers and private paths; catch a moved remote; full gate; forward-only bookmark move; branch-protection bypass warnings; explicit published-history rewrites. Use before any jj git push or git push. For creating, describing or splitting the commit itself, use commit.'
---

# 10x Push

A push publishes every commit between `<bookmark>@<remote>` and the local bookmark, including commits other sessions wrote and left unpushed. Audit that whole set, not only the change just made: nothing upstream did. jj never runs git hooks, so an outgoing message may never have been linted.

## MUST DO

1. **Explicit ask.** Push only on an explicit request in the current exchange. An approval given earlier, or for another repo, does not carry over.
2. **Fetch, then check the remote did not move.** Run `jj git fetch`. If `jj log -r '<bookmark>@<remote> & ::<bookmark>'` is empty, the remote moved: report what landed (`jj log -r '<bookmark>..<bookmark>@<remote>'`) and stop. Rebase onto it only when asked.
3. **Audit the outgoing set.** From the repo root, run `scripts/audit-outgoing.sh <bookmark> [remote]` (path relative to this skill). It lists every outgoing commit, runs the repo's `commit-msg` hook on each message (Conventional Commits and 72/100 when there is none), and fails on agent attribution (`Co-Authored-By`, `Generated with`), empty descriptions, private paths (`.claude/`, `.env`) and conflicts. On any `FAIL`, stop. Fix an unpushed commit through `commit` (describe, split), then rerun the audit.
4. **Show what goes out.** Before pushing, state how many commits the push publishes. When any were not made in this session, list them (hash, author, date, subject): they go public on the strength of this request, and the user must know it.
5. **Gate.** Run the full gate CI uses (`make ci`, else `make audit`) on the tip being pushed, not `make test` alone.
6. **Bookmark.** Confirm `jj bookmark list` points at the tip and tracks the remote; create or track explicitly (`jj bookmark create <name>`, `jj bookmark track <name>@<remote>`). Do not push first and retry missing or untracked errors.
7. **Push and read the server.** `jj git push --bookmark <name>` must print `Move forward bookmark <name> from <old> to <new>`. Read every `remote:` line. `Bypassed rule violations` means branch protection let an admin skip required checks or a pull request: quote it to the user; never report a plain success.
8. **Verify.** `jj git fetch`, then `<bookmark>@<remote>` must equal the pushed commit.

Under `set -o pipefail`, capture jj output before matching (`out=$(jj bookmark list 2>/dev/null || true)`, then `grep -q ... <<<"$out"`). Piping jj into `grep -q` can give jj a broken-pipe exit 3 and fake a missing bookmark.

## Rewriting published history

Only when the user explicitly asks for it in the current message, typically to remove a leaked trailer or secret. Never propose it to tidy history.

1. Fetch. List every commit the rewrite moves, including any landed on the remote since (bot merges, other contributors). If that set is larger than what the user approved, say so before going on.
2. Rewrite with `--ignore-immutable` (for example `jj describe --ignore-immutable -r <rev> --stdin`). When only messages change, `jj diff --from <bookmark>@<remote> --to <bookmark>` must be empty.
3. Rerun the audit, then push. jj moves the bookmark sideways and refuses if the remote moved after the fetch; that refusal means: fetch and start over.
4. Report the rewritten hashes, that existing clones must re-sync, and that old hashes stay reachable by direct URL. A leaked secret must be rotated: a rewrite does not unpublish it.

## MUST NOT

- Push when the audit fails, or audit only the session's commits.
- Use `--allow-backwards`, `git push --force` or `--ignore-immutable` outside an explicitly requested rewrite.
- Report a push that printed `Bypassed rule violations` as a clean success.

## Done when

- `audit-outgoing.sh` exited 0 on the set that was pushed, and the user saw the count plus any commits not made in this session.
- The full gate passed on the pushed tip.
- `jj git push` exited 0 and moved the bookmark forward (sideways only for a requested rewrite), and any `remote:` bypass lines were relayed.
- After a fetch, `<bookmark>@<remote>` is the pushed commit.
