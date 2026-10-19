#!/bin/sh
# audit-outgoing.sh [bookmark] [remote]: audit every commit a push of
# <bookmark> would publish, not only the ones this session wrote.
#
# jj never runs git hooks, so the repo's commit-msg hook is run here, once per
# outgoing message. Without one, the Conventional Commits header and the
# 72/100 length fallback apply. Prints the outgoing list (author, date,
# subject) for the confirmation, then one FAIL line per problem.
# Exit 0 clean, 1 at least one FAIL, 2 usage or repository error.
set -eu

bookmark=${1:-main}
remote=${2:-origin}

root=$(jj root 2>/dev/null) || { echo "audit-outgoing: not a jj repository" >&2; exit 2; }
jj log -r "$bookmark" --no-graph -T '""' >/dev/null 2>&1 \
  || { echo "audit-outgoing: no local bookmark $bookmark" >&2; exit 2; }

if jj log -r "$bookmark@$remote" --no-graph -T '""' >/dev/null 2>&1; then
  outgoing="$bookmark@$remote..$bookmark"
else
  outgoing="::$bookmark ~ ::remote_bookmarks(remote=exact:\"$remote\")"
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
jj log -r "$outgoing" --no-graph -T 'commit_id ++ "\n"' >"$tmp/ids"
if [ ! -s "$tmp/ids" ]; then
  echo "audit-outgoing: nothing to push: $bookmark is not ahead of $bookmark@$remote"
  exit 0
fi

hooks_dir=$(git -C "$root" config core.hooksPath 2>/dev/null || true)
case "$hooks_dir" in
  '') hooks_dir="$root/.git/hooks" ;;
  "~"/*) hooks_dir="$HOME/${hooks_dir#"~"/}" ;;
esac
hook=""
[ -x "$hooks_dir/commit-msg" ] && hook="$hooks_dir/commit-msg"

conventional='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9/_.-]+\))?!?: .+'
fails=0
fail() { echo "FAIL $1: $2"; fails=$((fails + 1)); }
oneline() { tr '\n' ' '; }

echo "Outgoing to $remote/$bookmark ($(wc -l <"$tmp/ids" | tr -d ' ') commits):"
jj log -r "$outgoing" --no-graph \
  -T 'commit_id.short(12) ++ "  " ++ author.name() ++ "  " ++ author.timestamp().format("%Y-%m-%d") ++ "  " ++ description.first_line() ++ "\n"'

# Hooks and jj read stdin; the ids come in on fd 3 so neither can swallow them.
while read -r id <&3; do
  short=$(printf %.12s "$id")
  msg="$tmp/msg"
  jj log -r "$id" --no-graph -T description >"$msg" </dev/null

  if [ ! -s "$msg" ]; then fail "$short" "empty description"; continue; fi
  if line=$(grep -inE 'co-authored-by:|generated with|noreply@anthropic\.com' "$msg"); then
    fail "$short" "agent attribution: $line"
  fi
  if [ -n "$hook" ]; then
    out=$("$hook" "$msg" 2>&1 </dev/null) \
      || fail "$short" "commit-msg hook rejects: $(printf '%s' "$out" | oneline)"
  else
    header=$(head -n 1 "$msg")
    printf '%s\n' "$header" | grep -qE "$conventional" \
      || fail "$short" "header is not Conventional Commits: $header"
    [ "$(printf '%s' "$header" | wc -m)" -le 72 ] || fail "$short" "header longer than 72 characters"
    if awk 'NR > 1 && length > 100 { found = 1 } END { exit !found }' "$msg"; then
      fail "$short" "body line longer than 100 characters"
    fi
  fi
  if paths=$(jj diff -r "$id" --name-only </dev/null | grep -E '(^|/)(\.claude/|\.env$)'); then
    fail "$short" "publishes private paths: $(printf '%s' "$paths" | oneline)"
  fi
done 3<"$tmp/ids"

conflicted=$(jj log -r "($outgoing) & conflicts()" --no-graph -T 'commit_id.short(12) ++ " "')
[ -z "$conflicted" ] || fail "$conflicted" "carries unresolved conflicts"

if [ "$fails" -gt 0 ]; then
  echo "audit-outgoing: $fails problem(s); do not push"
  exit 1
fi
echo "audit-outgoing: clean${hook:+ (messages checked by $hook)}"
