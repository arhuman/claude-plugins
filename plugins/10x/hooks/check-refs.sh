#!/bin/sh
# PostToolUse hook: after a Write/Edit on a prose file, warn about referenced
# scripts that exist nowhere in the repo (the documented-but-nonexistent class).
# Warning only, and scripts only: a path checker that cries wolf gets disabled.
# Resolve through symlinks: the installer links these hooks into a config tree,
# where dirname "$0" is the link's directory and lib.sh would not be found.
_self=$0
while [ -L "$_self" ]; do
  _link=$(readlink "$_self")
  case "$_link" in /*) _self=$_link ;; *) _self=$(dirname "$_self")/$_link ;; esac
done
. "$(dirname "$_self")/lib.sh"
hook_payload
fp=$(hook_field file_path)
case "$fp" in
  *.md|*.html) [ -f "$fp" ] || exit 0 ;;
  *) exit 0 ;;
esac

dir=$(cd "$(dirname "$fp")" 2>/dev/null && pwd) || exit 0

# The nearest .git or .jj is the project. A secondary jj workspace has no .git,
# and git rev-parse would answer for whatever repo encloses it. Same rule as
# scripts/lib.sh repo_files, duplicated: this hook ships without that file.
# --ignore-working-copy keeps the hook read-only (no snapshot per edit).
root=$dir
while [ "$root" != / ] && [ ! -e "$root/.git" ] && [ ! -d "$root/.jj" ]; do
  root=$(dirname "$root")
done
if [ -e "$root/.git" ]; then
  tracked=$(cd "$root" && git ls-files --cached --others --exclude-standard 2>/dev/null)
elif [ -d "$root/.jj" ]; then
  tracked=$(cd "$root" && jj --ignore-working-copy file list 2>/dev/null)
else
  root=$dir
  tracked=""
fi

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
