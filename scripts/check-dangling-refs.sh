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
set -u

NAMES='10x-review
teachme
introspect'

offenders=$(
  printf '%s\n' "$NAMES" | while read -r name; do
    [ -n "$name" ] || continue
    grep -rIln -F -- "$name" plugins/ README.md .github/ 2>/dev/null \
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
