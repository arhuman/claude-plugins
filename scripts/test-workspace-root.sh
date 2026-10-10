#!/bin/sh
# Run the repo-root scripts from a secondary jj workspace nested inside an
# unrelated git repo, the layout concurrency.md prescribes for parallel loop
# sessions. Such a workspace has no .git, so `git rev-parse` walks up to the
# enclosing repo: the scripts then tested the wrong tree, and the
# personal-paths check listed nothing and reported clean.
#
# Needs jj, which CI does not install: run it locally, it is not part of
# make check. A missing jj is a failure, not a skip.
#
# Usage: sh scripts/test-workspace-root.sh
set -u

REPO=$(cd "$(dirname "$0")/.." && pwd)
command -v jj >/dev/null 2>&1 || { echo "FAIL workspace-root: jj is required"; exit 1; }

WORK=$(mktemp -d) || exit 1
NAME="test-ws-$$"
WS="$WORK/outer/ws"
cleanup() {
  if [ -d "$WS" ]; then
    id=$(jj -R "$WS" log -r @ --no-graph -T change_id 2>/dev/null)
    jj -R "$REPO" workspace forget "$NAME" >/dev/null 2>&1
    [ -n "$id" ] && jj -R "$REPO" abandon "$id" >/dev/null 2>&1
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

git init -q "$WORK/outer" || exit 1
# The enclosing repo ignores the workspace, as a dotfiles repo at $HOME does
# its project trees: git then lists nothing there, which must not read as clean.
printf '/ws/\n' > "$WORK/outer/.gitignore"
jj -R "$REPO" workspace add --name "$NAME" -r @ "$WS" >/dev/null 2>&1 \
  || { echo "FAIL workspace-root: jj workspace add failed"; exit 1; }

fail=0
pass=0

# expect <label> <want-exit> <want-substring> <command...>
expect() {
  label=$1 want_exit=$2 want_text=$3
  shift 3
  out=$(cd "$WS" && "$@" 2>&1)
  got=$?
  if [ "$got" != "$want_exit" ] || ! printf '%s' "$out" | grep -q "$want_text"; then
    echo "FAIL $label: exit $got (want $want_exit), want output containing '$want_text'"
    printf '%s\n' "$out" | tail -5 | sed 's/^/  /'
    fail=$((fail + 1))
    return
  fi
  pass=$((pass + 1))
}

expect "hooks" 0 'hooks: [0-9]* passed, 0 failed' sh scripts/test-hooks.sh --harness claude
expect "claim" 0 'done: [0-9]* passed, 0 failed' sh scripts/test-claim.sh
expect "personal-paths/clean" 0 'No home-directory paths' sh scripts/check-no-personal-paths.sh

# Built at run time: the literal would be a leak in this file.
printf 'cd /%s/someone/project\n' Users > "$WS/planted.md"
expect "personal-paths/planted" 1 'PERSONAL PATH: planted.md' sh scripts/check-no-personal-paths.sh

echo "workspace-root: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
