#!/bin/sh
# inventory.sh - derive the plugin catalogue from the files themselves.
# Usage: inventory.sh [plugin-root]     (default: the 10x plugin this lives in)
#        inventory.sh --commands | --skills | --agents | --scripts
#
# The catalogue is DERIVED, never written by hand. A hand-maintained command
# list is how plugins/10x/README.md ended up citing 3 commands out of 8: nothing
# fails when it drifts, so it drifts. Reading the frontmatter cannot go stale
# without the file itself going stale.
set -eu

# Resolve the plugin root from this script's location, so it works from anywhere.
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT="${1:-}"
case "$ROOT" in
  ""|--*) ROOT=$(CDPATH= cd -- "$here/../../.." && pwd) ;;
esac
[ -d "$ROOT/commands" ] || { echo "inventory: no commands/ under $ROOT" >&2; exit 1; }

WHAT="all"
for a in "$@"; do
  case "$a" in
    --commands|--skills|--agents|--scripts) WHAT=${a#--} ;;
  esac
done

# First sentence of a frontmatter value: everything up to the first ". " that
# ends a sentence. Descriptions here are several sentences long by design (they
# carry the "not for X" clause), and a catalogue needs one line.
first_sentence() {
  # YAML single-quoted scalars escape an apostrophe by doubling it.
  printf '%s' "$1" | sed "s/^['\"]//; s/['\"]\$//; s/''/'/g" | awk '
    { line = $0
      n = index(line, ". ")
      if (n > 0) print substr(line, 1, n)
      else print line
      exit }'
}

# Value of a frontmatter key, from the leading --- block only.
fm() {
  awk -v key="$2" '
    NR==1 && $0!="---" { exit }
    NR==1 { next }
    /^---[ \t]*$/ { exit }
    index($0, key ":") == 1 {
      v = substr($0, length(key)+2)
      sub(/^[ \t]+/, "", v)
      print v
      exit }
  ' "$1"
}

commands() {
  echo "## Commands"
  for f in "$ROOT"/commands/*.md; do
    [ -e "$f" ] || continue
    name=$(basename "$f" .md)
    desc=$(first_sentence "$(fm "$f" description)")
    hint=$(fm "$f" argument-hint | sed "s/^['\"]//; s/['\"]$//")
    printf '/10x:%s\t%s\t%s\n' "$name" "${hint:--}" "${desc:-(no description)}"
  done
}

skills() {
  echo "## Skills"
  for d in "$ROOT"/skills/*/; do
    f="$d/SKILL.md"
    [ -f "$f" ] || continue
    name=$(fm "$f" name)
    [ -n "$name" ] || name=$(basename "$d")
    desc=$(first_sentence "$(fm "$f" description)")
    # Exposed by a command only when a command file bears the skill's own name
    # (plan.md -> 10x-plan). "Load the X skill" would also match a skill that a
    # command merely delegates to: /10x:loop uses 10x-commit but does not expose it.
    short=${name#10x-}
    cmd=""
    for c in "$ROOT"/commands/*.md; do
      [ -e "$c" ] || continue
      b=$(basename "$c" .md)
      [ "$b" = "$short" ] && { cmd=$b; break; }
    done
    [ -n "$cmd" ] || cmd=$(grep -lsE "^- Full workflow: \`$name\`|Load the \`$name\` skill" "$ROOT"/commands/*.md 2>/dev/null | head -1 | xargs -r basename | sed 's/\.md$//')
    printf '%s\t%s\t%s\n' "$name" "${cmd:+/10x:$cmd}" "${desc:-(no description)}"
  done
}

agents() {
  echo "## Agents"
  for f in "$ROOT"/agents/*.md; do
    [ -e "$f" ] || continue
    name=$(fm "$f" name); [ -n "$name" ] || name=$(basename "$f" .md)
    desc=$(first_sentence "$(fm "$f" description)")
    printf '%s\t%s\n' "$name" "${desc:-(no description)}"
  done
}

# Executable references, the part of the plugin that runs rather than instructs.
scripts() {
  echo "## Scripts"
  find "$ROOT" -name '*.sh' -not -path '*/node_modules/*' 2>/dev/null | sort | while read -r f; do
    rel=${f#"$ROOT"/}
    desc=$(sed -n '2,4p' "$f" | grep -m1 '^# ' | sed 's/^# //; s/^[a-z0-9._-]* - //')
    printf '%s\t%s\n' "$rel" "${desc:-(no header comment)}"
  done
}

case "$WHAT" in
  commands) commands ;;
  skills)   skills ;;
  agents)   agents ;;
  scripts)  scripts ;;
  all)      commands; echo; skills; echo; agents; echo; scripts ;;
esac
