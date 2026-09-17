#!/bin/sh
# PostToolUse hook: after a Write/Edit on a prose file, warn about referenced
# scripts that exist nowhere in the repo (the documented-but-nonexistent class).
# Warning only, and scripts only: a path checker that cries wolf gets disabled.
command -v jq >/dev/null 2>&1 || exit 0
fp=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)
case "$fp" in
  *.md|*.html) [ -f "$fp" ] || exit 0 ;;
  *) exit 0 ;;
esac

dir=$(dirname "$fp")
root=$(cd "$dir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
[ -n "$root" ] || root=$dir
tracked=$(cd "$root" 2>/dev/null && git ls-files --cached --others --exclude-standard 2>/dev/null)

# Strip URLs (a host like docs.astral.sh is not a script) and <placeholders>,
# then require a non-alphanumeric after the extension so change_id.short() is
# not read as change_id.sh.
cands=$(sed -e 's#https\{0,1\}://[^ )]*##g' -e 's/<[^>]*>//g' -e 's/$/ /' "$fp" \
  | grep -oE '((scripts|hooks|bin|\.claude)/)?[A-Za-z0-9._-]+\.(sh|py)[^A-Za-z0-9]' \
  | sed 's/.$//' | sort -u)

# A doc may legitimately cite a script in another repo. Collect the absolute
# directories named anywhere in the file and accept a basename that resolves
# under one of them: without this, every cross-repo reference reads as phantom
# and the advice to "create it" is wrong.
extdirs=$(grep -oE '/[A-Za-z0-9._/-]+/' "$fp" | sort -u)

missing=""
for p in $cands; do
  base=${p##*/}
  [ -e "$root/$p" ] && continue
  [ -e "$dir/$p" ] && continue
  printf '%s\n' "$tracked" | grep -qE "(^|/)${base}\$" && continue
  found=""
  for d in $extdirs; do
    [ -e "$d$base" ] && { found=1; break; }
    [ -e "$d$p" ] && { found=1; break; }
  done
  [ -n "$found" ] && continue
  missing="$missing $p"
done

[ -n "$missing" ] || exit 0
printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"Phantom reference check on %s: no file matching%s exists anywhere in the repo. Verify with ls, then create it, fix the path, or phrase it as a proposal instead of a fact."}}\n' "$fp" "$missing"
exit 0
