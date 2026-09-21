#!/bin/sh
# Guard against a canonical rule being restated outside the skill that owns it.
#
# A rule copied into a second skill drifts the moment the first one changes:
# when the comment rules were rewritten, three of four copies were updated and
# the fourth kept contradicting the canonical section until a review caught it.
# Consumers must point at the owner, not restate it.
#
# Maintenance rule for the table below: use an OPERATIVE SENTENCE, never a
# heading. A heading like "No phantom references" is legitimately cited by other
# skills, so guarding it flags every pointer. The operative wording of a rule has
# no reason to appear twice.
#
# Ownership is a directory prefix, so a skill may state its rule in SKILL.md and
# elaborate it under its own references/.
set -u

# phrase|owning directory prefix
RULES='A plausible name is not evidence|plugins/10x/skills/thinking/
only when it reduces that amount of context|plugins/10x/skills/thinking/
does not automatically deserve a package|plugins/10x/skills/thinking/
inverts a genuine external dependency|plugins/10x/skills/lang-go/
one line, two at most|plugins/10x/skills/documentation-rules/
a lead, not a verdict|plugins/10x/skills/conform/'

offenders=$(
  printf '%s\n' "$RULES" | while IFS='|' read -r phrase owner; do
    [ -n "$phrase" ] || continue
    grep -rIl -F -- "$phrase" plugins/ 2>/dev/null | while read -r hit; do
      # Prefix test rather than `case`: bash 3.2, which is /bin/sh on macOS,
      # mis-parses the `)` of a case pattern inside $( ) as the closing paren.
      if [ "${hit#"$owner"}" = "$hit" ]; then
        printf '%s\n  restates a rule owned by %s\n  phrase: "%s"\n' "$hit" "$owner" "$phrase"
      fi
    done
  done
)

if [ -n "$offenders" ]; then
  echo "Canonical rule restated outside its owning skill:"
  echo
  echo "$offenders"
  echo
  echo "Replace the copy with a pointer at the owning skill, or, if the rule genuinely"
  echo "moved, update the owner in scripts/check-rule-duplication.sh."
  exit 1
fi

exit 0
