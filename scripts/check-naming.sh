#!/bin/sh
# One slug policy (CONTRIBUTING.md "Naming"): every id this repo ships is
# lowercase kebab-case, ASCII only, no underscore, no whitespace, no path
# separator. Walks the five source surfaces plus the generated opencode/
# tree, since a generator bug could reintroduce an underscore there even
# after the source is clean.
#
# Also flags a command and a skill sharing a stem, UNLESS the pair is one of
# the documented exceptions below: a command that exists only to invoke the
# skill of the same name (its body says so) is a deliberate pairing, not an
# accidental collision. Any other repeated stem across surfaces is reported,
# not forbidden: two commands named the same by coincidence still need a
# human decision, which a hard failure would preempt.
set -u
. "$(dirname "$0")/lib.sh"

# command/skill stem pairs where the command's sole job is "run this skill":
# reported by a human, not by this check, so adding a new one is a one-line
# edit here instead of a design discussion. Kept short on purpose.
DOCUMENTED_PAIRS='loop
manual
senior-voice'

fail=0

is_kebab() {
  # lowercase letters, digits, single hyphens between segments; no leading,
  # trailing or doubled hyphen.
  case "$1" in
    ''|-*|*-) return 1 ;;
    *--*) return 1 ;;
    *[!a-z0-9-]*) return 1 ;;
    *) return 0 ;;
  esac
}

check_stem() {
  # check_stem <surface> <stem> <file>
  surface=$1 stem=$2 file=$3
  if ! is_kebab "$stem"; then
    echo "not kebab-case: $surface $stem ($file)"
    fail=1
  fi
}

cmd_stems=$(for f in $(plugin_commands); do basename "$f" .md; done | sort -u)
agent_stems=$(for f in $(plugin_agents); do basename "$f" .md; done | sort -u)
skill_stems=$(for f in $(plugin_skills); do basename "$(dirname "$f")"; done | sort -u)
hook_stems=$(
  for f in plugins/10x/hooks/*.sh; do
    [ -f "$f" ] || continue
    b=$(basename "$f" .sh)
    [ "$b" = lib ] && continue
    echo "$b"
  done | sort -u
)

for f in $(plugin_commands); do check_stem Command "$(basename "$f" .md)" "$f"; done
for f in $(plugin_agents); do check_stem Agent "$(basename "$f" .md)" "$f"; done
for f in $(plugin_skills); do check_stem Skill "$(basename "$(dirname "$f")")" "$f"; done
for f in plugins/10x/hooks/*.sh; do
  [ -f "$f" ] || continue
  b=$(basename "$f" .sh)
  [ "$b" = lib ] && continue
  check_stem Hook "$b" "$f"
done

# The generated tree: commands keep the 10x- prefix, agents do not.
for f in $(gen_commands); do
  stem=${f##*/}
  stem=${stem#10x-}
  stem=${stem%.md}
  check_stem "Generated command" "$stem" "$f"
done
for f in $(gen_agents); do check_stem "Generated agent" "$(basename "$f" .md)" "$f"; done

# Cross-surface collisions: a stem present in more than one of
# command/agent/skill/hook, minus the documented pairs.
overlap=$(printf '%s\n%s\n%s\n%s\n' "$cmd_stems" "$agent_stems" "$skill_stems" "$hook_stems" \
  | sed '/^$/d' | sort | uniq -d)
for stem in $overlap; do
  if printf '%s\n' "$DOCUMENTED_PAIRS" | grep -qx "$stem"; then
    continue
  fi
  echo "cross-surface collision on '$stem': not a documented pair, needs a rename or an entry in DOCUMENTED_PAIRS"
  fail=1
done

[ "$fail" -eq 0 ] && echo "check-naming: every id is kebab-case, no undocumented collision."
exit $fail
