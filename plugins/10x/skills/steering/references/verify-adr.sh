#!/bin/sh
# verify-adr.sh — check docs/adr/ against ADR Contract v1.
# Usage: verify-adr.sh [adr-dir]   (default: docs/adr)
# Exits 0 if conformant, 1 if any violation is found. Safe to wire into CI.
set -eu

DIR="${1:-docs/adr}"
fail=0
warn() { printf 'ADR: %s\n' "$1" >&2; fail=1; }

[ -d "$DIR" ] || { echo "ADR: no $DIR/ (no ADRs yet) — ok"; exit 0; }

# Monolithic stores masquerading as ADR homes.
[ -f docs/ADR.md ]        && warn "monolithic store docs/ADR.md — split into $DIR/NNNN-slug.md"
[ -f "$DIR/IN-FLIGHT.md" ] && warn "monolithic store $DIR/IN-FLIGHT.md — split into per-decision files"

seen=""
for f in "$DIR"/*.md; do
  [ -e "$f" ] || continue
  b=$(basename "$f")
  case "$b" in
    README.md|INBOX.md) continue ;;            # generated index / labelled scratchpad
  esac

  # Filename must be NNNN-slug.md.
  echo "$b" | grep -qE '^[0-9]{4}-[a-z0-9][a-z0-9-]*\.md$' \
    || { warn "$b: filename is not NNNN-slug.md"; continue; }

  num=$(echo "$b" | cut -c1-4)
  case " $seen " in *" $num "*) warn "$b: duplicate number $num" ;; esac
  seen="$seen $num"

  # Frontmatter status + date.
  fm=$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$f")
  echo "$fm" | grep -qE '^status:[[:space:]]*(proposed|accepted|deprecated|superseded)[[:space:]]*$' \
    || warn "$b: missing/invalid 'status:' (proposed|accepted|deprecated|superseded)"
  echo "$fm" | grep -qE '^date:[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]*$' \
    || warn "$b: missing/invalid 'date: YYYY-MM-DD'"

  # Title heading present and NOT numbered / not 'ADR ...'.
  title=$(grep -m1 '^# ' "$f" || true)
  [ -n "$title" ] || warn "$b: no '# Title' heading"
  echo "$title" | grep -qiE '^#[[:space:]]+([0-9]|ADR[[:space:]-])' \
    && warn "$b: title carries a number/ADR prefix — id comes from the filename"

  grep -qE '^##[[:space:]]+Decision' "$f" || warn "$b: no '## Decision' section"

  # Supersede integrity.
  if echo "$fm" | grep -qE '^status:[[:space:]]*superseded'; then
    echo "$fm" | grep -qE '^superseded_by:[[:space:]]*[0-9]{4}' \
      || warn "$b: status superseded but no 'superseded_by: NNNN'"
  fi
  for ref in $(echo "$fm" | sed -nE 's/^(superseded_by|supersedes):[[:space:]]*([0-9]{4}).*/\2/p'); do
    ls "$DIR/$ref"-*.md >/dev/null 2>&1 || warn "$b: references ADR $ref which does not exist"
  done
done

[ "$fail" -eq 0 ] && echo "ADR: docs/adr/ conformant (ADR Contract v1)"
exit "$fail"
