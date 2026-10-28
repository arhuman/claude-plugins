#!/bin/sh
# PostToolUse hook on Bash: check the files an in-place perl or sed edit just
# rewrote. thinking limits these edits to bulk single-line substitutions, and
# the damage they still do (a Go file that no longer parses or formats, text
# no longer valid UTF-8) is mechanical, so it is caught here instead of at the
# next make ci. exit 2 feeds the message back to the model.
#
# Garbled lines that still parse are out of reach: the rule asks for a diff
# review after the edit, which no hook can do for the model.
# Resolve through symlinks: the installer links these hooks into a config tree,
# where dirname "$0" is the link's directory and lib.sh would not be found.
_self=$0
while [ -L "$_self" ]; do
  _link=$(readlink "$_self")
  case "$_link" in /*) _self=$_link ;; *) _self=$(dirname "$_self")/$_link ;; esac
done
. "$(dirname "$_self")/lib.sh"
hook_payload
cmd=$(hook_field command)
printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_.-])(perl|sed)[[:space:]]([^|;&]*[[:space:]])?-[[:alnum:]]*i' || exit 0

dir=$(hook_cwd)
cd "$dir" 2>/dev/null || exit 0

# The files are the command's words that name existing files, globs expanded
# by the shell exactly as the edit saw them; nothing is executed. A pipeline
# that feeds names through xargs carries none, so fall back to what changed
# under the working directory in the last minute.
files=$(
  # shellcheck disable=SC2086
  for w in $cmd; do
    w=${w#[\"\']}
    w=${w%[\"\']}
    [ -f "$w" ] && printf '%s\n' "$w"
  done | sort -u
)
if [ -z "$files" ]; then
  files=$(find . \( -name .git -o -name .jj -o -name node_modules -o -name vendor -o -name .venv \) -prune \
    -o -type f -mmin -1 -print 2>/dev/null | head -200)
fi
[ -n "$files" ] || exit 0

report=""
gofiles=$(printf '%s\n' "$files" | grep '\.go$')
if [ -n "$gofiles" ]; then
  if command -v gofmt >/dev/null 2>&1; then
    # gofmt -l names an unformatted file and -e prints every parse error;
    # either one fails make ci, so both are reported.
    out=$(printf '%s\n' "$gofiles" | tr '\n' '\0' | xargs -0 gofmt -l -e 2>&1)
    [ -n "$out" ] && report="gofmt:
$out"
  else
    echo "10x hooks: gofmt missing, Go files not checked" >&2
  fi
fi

bad_utf8=$(printf '%s\n' "$files" | python3 -c '
import sys
for p in sys.stdin.read().splitlines():
    try: b=open(p,"rb").read()
    except OSError: continue
    if b"\0" in b: continue
    try: b.decode("utf-8")
    except UnicodeDecodeError as e: print(f"{p}: invalid UTF-8 at byte {e.start}")
' 2>/dev/null)
[ -n "$bad_utf8" ] && report="${report:+$report
}$bad_utf8"

[ -n "$report" ] || exit 0
printf '%s\n' "$report" >&2
echo "the in-place perl/sed edit you just ran in $dir left the files above broken. Repair them with Edit, then read the diff of every file the command touched. For changes like this one, use Edit instead (thinking, Surgical Changes)." >&2
exit 2
