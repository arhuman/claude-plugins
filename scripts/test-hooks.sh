#!/bin/sh
# Feed fixed PostToolUse payloads to the three hooks and assert exit code and
# output. The degraded-dependency cases are the point: the hooks were silently
# inert without jq, so "reports nothing" must be a test failure, not a pass.
#
# Usage: sh scripts/test-hooks.sh [--harness claude|opencode]
# Without --harness both run. claude feeds the hooks directly; opencode feeds
# OpenCode-shaped tool.execute.after events through the generated adapter
# (opencode/plugins/10x-hooks.js) and reads what it appends to the tool
# output, which is the only channel a hook has to the model there.
set -u

REPO=$(git rev-parse --show-toplevel 2>/dev/null) || REPO=$(cd "$(dirname "$0")/.." && pwd)
HOOKS="$REPO/plugins/10x/hooks"
ADAPTER="$REPO/opencode/plugins/10x-hooks.js"
WORK=$(mktemp -d) || exit 1
trap 'rm -rf "$WORK"' EXIT

HARNESS=all
case "${1:-}" in
  "") ;;
  --harness)
    case "${2:-}" in
      claude|opencode) HARNESS=$2 ;;
      *) echo "usage: sh scripts/test-hooks.sh [--harness claude|opencode]" >&2; exit 2 ;;
    esac
    ;;
  *) echo "usage: sh scripts/test-hooks.sh [--harness claude|opencode]" >&2; exit 2 ;;
esac

fail=0
pass=0

# check <label> <hook> <expected-exit> <expected-substring-or-empty> <<payload
check() {
  label=$1 hook=$2 want_exit=$3 want_text=$4
  out=$(sh "$HOOKS/$hook" 2>&1)
  got=$?
  if [ "$got" != "$want_exit" ]; then
    echo "FAIL $label: exit $got, want $want_exit"
    fail=$((fail + 1))
    return
  fi
  if [ -n "$want_text" ] && ! printf '%s' "$out" | grep -q "$want_text"; then
    echo "FAIL $label: output missing '$want_text'"
    printf '  got: %s\n' "$out"
    fail=$((fail + 1))
    return
  fi
  if [ -z "$want_text" ] && [ -n "$out" ]; then
    echo "FAIL $label: expected silence, got: $out"
    fail=$((fail + 1))
    return
  fi
  pass=$((pass + 1))
}

md="$WORK/doc.md"
printf 'clean prose line\n' > "$md"

if [ "$HARNESS" != opencode ]; then

# --- check-dashes.sh -------------------------------------------------------

check "dashes/write-violating" check-dashes.sh 2 'em/en dash' <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$md","content":"a line with an — dash"}}
EOF

check "dashes/write-clean" check-dashes.sh 0 "" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$md","content":"a clean line, punctuated properly"}}
EOF

# A dash already present in the surrounding context of an Edit is not something
# the model just wrote: old_string carries it, so it must not be reported.
check "dashes/edit-preexisting-context" check-dashes.sh 0 "" <<EOF
{"tool_name":"Edit","tool_input":{"file_path":"$md","old_string":"legacy line with — dash","new_string":"legacy line with — dash\nan added clean line"}}
EOF

check "dashes/edit-new-dash" check-dashes.sh 2 'em/en dash' <<EOF
{"tool_name":"Edit","tool_input":{"file_path":"$md","old_string":"legacy line","new_string":"legacy line\nfreshly written — dash"}}
EOF

check "dashes/en-dash" check-dashes.sh 2 'em/en dash' <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$md","content":"a range 10–20 written as prose"}}
EOF

# Non-prose extension: a dash in code or data can be load-bearing.
check "dashes/code-file-ignored" check-dashes.sh 0 "" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$WORK/x.go","content":"// a — dash in code"}}
EOF

check "dashes/multi-edit" check-dashes.sh 2 'em/en dash' <<EOF
{"tool_name":"Edit","tool_input":{"file_path":"$md","edits":[{"old_string":"a","new_string":"a"},{"old_string":"b","new_string":"b with — dash"}]}}
EOF

# --- check-claude-md.sh ----------------------------------------------------

check "claude-md/triggers" check-claude-md.sh 0 '10x:plan check' <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$WORK/CLAUDE.md","content":"anything"}}
EOF

check "claude-md/other-file-silent" check-claude-md.sh 0 "" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$md","content":"anything"}}
EOF

# --- check-refs.sh ---------------------------------------------------------

printf 'Run `scripts/definitely-absent-xyz.sh` to proceed.\n' > "$WORK/phantom.md"
check "refs/phantom-reported" check-refs.sh 0 'Phantom reference check' <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$WORK/phantom.md","content":"ignored, the hook reads the file"}}
EOF

printf 'Nothing but prose here.\n' > "$WORK/noscript.md"
check "refs/no-reference-silent" check-refs.sh 0 "" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$WORK/noscript.md","content":"ignored"}}
EOF

# --- invoked through a symlink ---------------------------------------------
#
# install-opencode.sh links hooks into a config tree, and dirname "$0" is then
# the link's directory, where lib.sh does not exist. Sourcing must follow the
# link to the real script instead.

linkdir="$WORK/linked"
mkdir -p "$linkdir"
for hook in check-dashes.sh check-refs.sh check-claude-md.sh; do
  ln -sf "$HOOKS/$hook" "$linkdir/$hook"
done

out=$(sh "$linkdir/check-dashes.sh" 2>&1 <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$md","content":"a line with an — dash"}}
EOF
)
got=$?
if [ "$got" != 2 ]; then
  echo "FAIL dashes/via-symlink: exit $got, want 2 (lib.sh must resolve through the link)"
  printf '  got: %s\n' "$out"
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# --- degraded dependency: the regression this suite exists for -------------
#
# Without python3 a hook cannot parse its payload. It must still exit 0 (never
# block an edit over a missing tool) and must say so. Silence here is the bug.

no_python_dir="$WORK/nopy"
mkdir -p "$no_python_dir"
for cmd in sh grep sed awk cat dirname git mktemp rm column; do
  p=$(command -v "$cmd" 2>/dev/null) && ln -sf "$p" "$no_python_dir/$cmd"
done

for hook in check-dashes.sh check-refs.sh check-claude-md.sh; do
  out=$(PATH="$no_python_dir" sh "$HOOKS/$hook" 2>&1 <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$md","content":"a line with an — dash"}}
EOF
)
  got=$?
  if [ "$got" != 0 ]; then
    echo "FAIL $hook/no-python: exit $got, want 0 (a missing tool must not block an edit)"
    fail=$((fail + 1))
  elif ! printf '%s' "$out" | grep -q 'python3 missing'; then
    echo "FAIL $hook/no-python: degraded silently, want a 'python3 missing' notice"
    printf '  got: %s\n' "$out"
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
done

fi # HARNESS != opencode

if [ "$HARNESS" != claude ]; then

# --- OpenCode: the same hooks behind the generated adapter ------------------
#
# Each case is a tool.execute.after event as OpenCode sends it (tool id and
# camelCase args) plus the tool output the model would read. The adapter
# must leave that output untouched when no hook reports, and append the
# hook's message when one does. The adapter is JavaScript; OpenCode runs it
# under Bun, the suite under whichever of node or bun is installed. Neither
# present is a failure, not a skip: a suite that skips proves nothing.

JS=$(command -v node 2>/dev/null || command -v bun 2>/dev/null || true)
if [ -z "$JS" ]; then
  echo "FAIL opencode/runtime: node or bun is required to drive $ADAPTER"
  fail=$((fail + 1))
fi

# oc_check <label> <expected-substring-or-empty> <<event
# The event's "output" field is always "tool result": silence means the
# adapter printed exactly that back.
oc_check() {
  label=$1 want_text=$2
  [ -n "$JS" ] || return
  out=$("$JS" "$ADAPTER" 2>"$WORK/stderr")
  got=$?
  if [ "$got" != 0 ]; then
    echo "FAIL opencode/$label: adapter exit $got"
    sed 's/^/  /' "$WORK/stderr"
    fail=$((fail + 1))
    return
  fi
  if [ -n "$want_text" ] && ! printf '%s' "$out" | grep -q "$want_text"; then
    echo "FAIL opencode/$label: tool output missing '$want_text'"
    printf '  got: %s\n' "$out"
    fail=$((fail + 1))
    return
  fi
  if [ -z "$want_text" ] && [ "$out" != "tool result" ]; then
    echo "FAIL opencode/$label: expected the tool output untouched, got: $out"
    fail=$((fail + 1))
    return
  fi
  pass=$((pass + 1))
}

oc_check "write-violating" 'em/en dash' <<EOF
{"tool":"write","args":{"filePath":"$md","content":"a line with an — dash"},"output":"tool result"}
EOF

oc_check "write-clean" "" <<EOF
{"tool":"write","args":{"filePath":"$md","content":"a clean line, punctuated properly"},"output":"tool result"}
EOF

oc_check "edit-preexisting-context" "" <<EOF
{"tool":"edit","args":{"filePath":"$md","oldString":"legacy line with — dash","newString":"legacy line with — dash\nan added clean line"},"output":"tool result"}
EOF

oc_check "edit-new-dash" 'em/en dash' <<EOF
{"tool":"edit","args":{"filePath":"$md","oldString":"legacy line","newString":"legacy line\nfreshly written — dash"},"output":"tool result"}
EOF

oc_check "code-file-ignored" "" <<EOF
{"tool":"write","args":{"filePath":"$WORK/x.go","content":"// a — dash in code"},"output":"tool result"}
EOF

oc_check "claude-md/triggers" '10x:plan check' <<EOF
{"tool":"write","args":{"filePath":"$WORK/CLAUDE.md","content":"anything"},"output":"tool result"}
EOF

printf 'Run `scripts/definitely-absent-xyz.sh` to proceed.\n' > "$WORK/phantom.md"
oc_check "refs/phantom-reported" 'Phantom reference check' <<EOF
{"tool":"write","args":{"filePath":"$WORK/phantom.md","content":"ignored, the hook reads the file"},"output":"tool result"}
EOF

# Any other tool is none of the hooks' business, whatever its args carry.
oc_check "other-tool-ignored" "" <<EOF
{"tool":"bash","args":{"command":"echo — dash"},"output":"tool result"}
EOF

# The message names the hook, so the model can tell a check from the tool's
# own output.
oc_check "names-the-hook" '\[10x hook check-dashes.sh\]' <<EOF
{"tool":"write","args":{"filePath":"$md","content":"a line with an — dash"},"output":"tool result"}
EOF

# install-opencode.sh links the adapter into ~/.config/opencode/plugins/; it
# must find hooks.json from its real path, not from the link's directory.
if [ -n "$JS" ]; then
  mkdir -p "$WORK/plugins"
  ln -sf "$ADAPTER" "$WORK/plugins/10x-hooks.js"
  out=$("$JS" "$WORK/plugins/10x-hooks.js" 2>"$WORK/stderr" <<EOF
{"tool":"write","args":{"filePath":"$md","content":"a line with an — dash"},"output":"tool result"}
EOF
)
  if printf '%s' "$out" | grep -q 'em/en dash'; then
    pass=$((pass + 1))
  else
    echo "FAIL opencode/via-symlink: hooks not found through the installed link"
    printf '  got: %s\n' "$out"
    sed 's/^/  /' "$WORK/stderr"
    fail=$((fail + 1))
  fi
fi

fi # HARNESS != claude

echo "hooks: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
