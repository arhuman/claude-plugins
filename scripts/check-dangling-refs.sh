#!/bin/sh
# Guard against the public tree citing a component that moved to the private
# marketplace or was removed (the e1d05ac split left exactly these dangling:
# 10x-review in skill-standard and the golangci docs, teachme in two
# catalogues, introspect in CI and the marketplace README).
#
# A name below is a component confirmed absent from this tree. Any mention in
# the shipped surface (plugins/, README.md, .github/) is a dangling reference:
# either the component came back public (remove it from NAMES) or the mention
# is stale (fix it). Design records under .claude/ legitimately keep the
# names and are not scanned.
#
# Names are matched literally and unanchored, so only names specific enough to
# be unambiguous belong here. The private skills rating, reporting, explaining,
# blogging, duowriting and teaching are listed in their qualified
# <plugin>/skills form instead of bare: bare "rating" also matches
# "integrating", and "reporting"/"explaining" occur as ordinary English
# throughout the skills. A bare entry that fires on prose gets silenced by
# deleting it, which is how a guard dies.
set -u
. "$(dirname "$0")/lib.sh"

NAMES='10x-review
10x-authoring
10x-learn
10x-introspect
teachme
introspect
review-agent
10x-authoring/skills
10x-learn/skills
10x-review/skills
10x-introspect/skills'

offenders=$(
  printf '%s\n' "$NAMES" | while read -r name; do
    [ -n "$name" ] || continue
    # shellcheck disable=SC2086 # the surface is a deliberate word list
    grep -rIln -F -- "$name" $SHIPPED_SURFACE 2>/dev/null \
      | grep -v '/\.claude/' \
      | sed "s|$| mentions: $name|"
  done | sort -u
)

if [ -n "$offenders" ]; then
  echo "Reference to a private or removed component in the shipped surface:"
  echo
  echo "$offenders"
  echo
  echo "Fix the stale mention, or remove the name from NAMES in"
  echo "scripts/check-dangling-refs.sh if the component is public again."
  exit 1
fi

exit 0
