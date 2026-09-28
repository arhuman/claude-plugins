#!/bin/sh
# Verify that every references/<file> mentioned in a SKILL.md exists, and warn
# about reference files never mentioned by their SKILL.md.
#
# Paths are resolved relative to the skill directory, so same-skill
# (references/x, ./references/x) and cross-skill/shared references
# (../_shared/references/x, ../other-skill/references/x) are all supported.
set -u
. "$(dirname "$0")/lib.sh"
fail=0
for skill in $(plugin_skills); do
  dir=$(dirname "$skill")
  for ref in $(grep -oE '((\.\.?/)+([A-Za-z0-9._-]+/)*)?references/[A-Za-z0-9._-]+' "$skill" | sort -u); do
    if [ ! -e "$dir/$ref" ]; then
      echo "MISSING: $skill -> $ref"
      fail=1
    fi
  done
  if [ -d "$dir/references" ]; then
    for f in "$dir"/references/*; do
      base=$(basename "$f")
      grep -q "$base" "$skill" || echo "WARN orphan (not mentioned in $skill): $f"
    done
  fi
done
exit $fail
