#!/bin/sh
# PostToolUse hook: flag em/en dashes in prose the model just wrote.
# The rule lives in CLAUDE.md and still drifts on long sessions, so it is
# enforced mechanically here. exit 2 feeds the message back to the model.
#
# Checks the written payload, not the whole file, so pre-existing dashes in a
# legacy document do not nag on every unrelated edit. Prose extensions only:
# a dash inside code or data can be load-bearing.
command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)
fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
case "$fp" in
  *.md|*.html|*.txt|*.tmpl) ;;
  *) exit 0 ;;
esac

written=$(printf '%s' "$input" | jq -r '
  [.tool_input.content?, .tool_input.new_string?, (.tool_input.edits[]?.new_string?)]
  | map(select(. != null)) | join("\n")' 2>/dev/null)
[ -n "$written" ] || { [ -f "$fp" ] && written=$(cat "$fp"); }
[ -n "$written" ] || exit 0

# An Edit's new_string carries unchanged context around the change, so a dash
# already in that context is not something the model just wrote. Drop every
# line the matching old_string also contained: without this the hook nags on
# pre-existing prose whenever an edit lands near it, which is the "cries wolf"
# failure that gets a checker disabled. Line-level, so a line genuinely edited
# to keep its dash still reports.
kept=$(printf '%s' "$input" | jq -r '
  [.tool_input.old_string?, (.tool_input.edits[]?.old_string?)]
  | map(select(. != null)) | join("\n")' 2>/dev/null)
if [ -n "$kept" ]; then
  keptfile=$(mktemp) || exit 0
  printf '%s\n' "$kept" > "$keptfile"
  written=$(printf '%s\n' "$written" | grep -vxF -f "$keptfile")
  rm -f "$keptfile"
fi
[ -n "$written" ] || exit 0

hits=$(printf '%s' "$written" | grep -n '—\|–')
[ -n "$hits" ] || exit 0

printf '%s\n' "$hits" >&2
echo "em/en dash in what you just wrote to $fp (lines above are payload-relative): replace each with a period, comma, colon or parentheses. Keep it only if the dash is data (a grep pattern, a quoted extract), and say so." >&2
exit 2
