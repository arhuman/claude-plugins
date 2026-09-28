#!/bin/sh
# The "Harness support" matrix in plugins/10x/README.md must match the tree.
#
# The matrix is prose and would drift like any catalogue: a command added
# without a row reads as unsupported everywhere, a row kept after a rename
# claims support for nothing. So both directions are checked: every surface
# file has exactly one row, every row names a file. A `generated` cell is
# also confirmed against the committed opencode/ tree, since that is the claim
# it makes. MCP rows are declarative (servers are not files here) and only
# their vocabulary is checked.
#
# Surfaces: commands/*.md and agents/*.md by stem, skills/<dir>/ carrying a
# SKILL.md plus _shared, hooks/*.sh minus lib.sh (sourced, not a hook) and
# hooks.json (the manifest that lists them, not a surface itself).
set -u
. "$(dirname "$0")/lib.sh"

README=$PLUGIN_ROOT/README.md
[ -f "$README" ] || { echo "missing $README"; exit 1; }

fail=0
tmp=$(mktemp)
# Rows of the matrix section only: from its heading to the next heading.
awk '/^## Harness support/{f=1; next} /^## /{f=0} f && /^\| (Command|Agent|Skill|Hook|MCP) \|/' "$README" > "$tmp"
[ -s "$tmp" ] || { echo "no Harness support rows found in $README"; rm -f "$tmp"; exit 1; }

# expected: one "<kind> <name>" per line, derived from the tree.
expected=$(
  for f in $(plugin_commands); do echo "Command $(basename "$f" .md)"; done
  for f in $(plugin_agents); do echo "Agent $(basename "$f" .md)"; done
  for f in $(plugin_skills); do echo "Skill $(basename "$(dirname "$f")")"; done
  echo "Skill _shared"
  for f in "$PLUGIN_ROOT"/hooks/*.sh; do
    [ "$(basename "$f")" = lib.sh ] && continue
    echo "Hook $(basename "$f" .sh)"
  done
)

listed=$(sed -E 's/^\| ([A-Za-z]+) \| `([^`]+)` \|.*/\1 \2/' "$tmp")

for e in $(printf '%s\n' "$expected" | tr ' ' ':'); do
  kind=${e%%:*}; name=${e#*:}
  n=$(printf '%s\n' "$listed" | grep -cx "$kind $name")
  if [ "$n" -eq 0 ]; then
    echo "no row for $kind $name in the Harness support matrix"
    fail=1
  elif [ "$n" -gt 1 ]; then
    echo "$n rows for $kind $name in the Harness support matrix"
    fail=1
  fi
done

while IFS= read -r line; do
  kind=${line%% *}; name=${line#* }
  case "$kind" in
    MCP) ;;
    *)
      if ! printf '%s\n' "$expected" | grep -qx "$kind $name"; then
        echo "row $kind $name names no file under $PLUGIN_ROOT"
        fail=1
      fi
      ;;
  esac
done <<EOF
$listed
EOF

# Cell vocabulary, and the generated claim against opencode/.
while IFS='|' read -r _ kind name claude opencode _rest; do
  kind=$(printf '%s' "$kind" | sed 's/^ *//; s/ *$//')
  name=$(printf '%s' "$name" | sed 's/^ *`//; s/` *$//')
  for cell in "$claude" "$opencode"; do
    v=$(printf '%s' "$cell" | sed 's/^ *//; s/ (.*//; s/ *$//')
    case "$v" in
      supported|generated|linked|unsupported) ;;
      *) echo "row $kind $name: cell '$v' is not supported|generated|linked|unsupported"; fail=1 ;;
    esac
  done
  case "$opencode" in
    *generated*)
      case "$kind" in
        Command) [ -f "opencode/commands/10x-$name.md" ] || { echo "row Command $name says generated but opencode/commands/10x-$name.md is missing"; fail=1; } ;;
        Agent) [ -f "opencode/agents/$name.md" ] || { echo "row Agent $name says generated but opencode/agents/$name.md is missing"; fail=1; } ;;
        *) echo "row $kind $name: only commands and agents are generated"; fail=1 ;;
      esac
      ;;
  esac
done < "$tmp"

rm -f "$tmp"
[ "$fail" -eq 0 ] && echo "Harness support matrix matches the tree."
exit $fail
