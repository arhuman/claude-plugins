#!/bin/sh
# The artifact registry (skills/_shared/references/artifacts.md) claims, per
# row, that a writer component produces a given path. This check keeps the
# table honest: the path's literal part must actually appear in that writer's
# own files, the same drift class check-rule-duplication.sh catches for prose
# rules. A failure is fixed by correcting the registry or the writer, never
# by weakening this match.
#
# Heuristic, matching the house grep style: the first backticked string in
# the row's first cell is the path pattern; the first token of the Writer
# cell resolves to a command file (/name), an agent file (name-agent), or a
# skill directory (anything else); the match literal is the prefix before
# the first <placeholder>, accepted as the full prefix or as the pattern's
# final-segment prefix alone (a prose mention may carry only the filename
# shape, not the directory). No looser fallback: trimming to a bare
# directory like .claude/doc/ would match almost any writer and check
# nothing. Writer "nobody" rows are skipped.
set -u

REGISTRY=plugins/10x/skills/_shared/references/artifacts.md
[ -f "$REGISTRY" ] || { echo "missing $REGISTRY"; exit 1; }

fail=0
tmp=$(mktemp)
grep -E '^\| `' "$REGISTRY" > "$tmp"

while IFS='|' read -r _ cell_path cell_writer _rest; do
  pattern=$(printf '%s' "$cell_path" | sed -n 's/[^`]*`\([^`]*\)`.*/\1/p')
  writer=$(printf '%s' "$cell_writer" | sed 's/^ *//; s/[ ,(].*//')
  [ -n "$pattern" ] || continue
  [ -n "$writer" ] || continue
  case "$writer" in nobody*) continue ;; esac

  case "$writer" in
    /*) target="plugins/10x/commands/${writer#/}.md" ;;
    *-agent) target="plugins/10x/agents/${writer}.md" ;;
    *) target="plugins/10x/skills/${writer}" ;;
  esac
  if [ ! -e "$target" ]; then
    echo "registry names writer '$writer' but $target does not exist"
    fail=1
    continue
  fi

  # Literal before the first placeholder; if the pattern starts with one,
  # take what follows the last placeholder instead.
  literal=${pattern%%<*}
  [ -n "$literal" ] || literal=${pattern##*>}
  lastseg=${literal##*/}

  found=0
  if grep -rqF -- "$literal" "$target" 2>/dev/null; then
    found=1
  elif [ -n "$lastseg" ] && [ "$lastseg" != "$literal" ] \
    && grep -rqF -- "$lastseg" "$target" 2>/dev/null; then
    found=1
  fi

  if [ "$found" -eq 0 ]; then
    echo "artifacts.md claims $writer writes $pattern, but neither '$literal' nor '$lastseg' appears under $target"
    fail=1
  fi
done < "$tmp"

rm -f "$tmp"
exit $fail
