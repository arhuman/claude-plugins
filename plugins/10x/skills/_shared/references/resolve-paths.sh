#!/bin/sh
# resolve-paths.sh - resolve the steering-document paths for a repo.
# Usage:
#   resolve-paths.sh            -> eval-able assignments for all artifacts
#   resolve-paths.sh UX         -> just that one path, bare
# Recognised keys: PRD TECH UX ADR CONTEXT PLANDIR ARCHIVES OWNERSHIP
#
# Why this exists: an artifact whose location depends on ownership has two
# spellings, and every consumer was resolving it independently. steering writes
# the UX contract to .claude/project/ux.md on a foreign repo (SKILL.md, the
# owned/foreign table), while verify-plan.sh defaulted UX to docs/ux.md and the
# loop gate tested docs/ux.md directly. On a foreign repo the writer and the
# readers therefore disagreed: the contract existed, and the gate that was
# supposed to enforce it silently skipped, reporting a pass because it could not
# find the file rather than because the file was conformant.
#
# One resolver, consulted by writers and readers alike, is what keeps a path
# from drifting to two spellings. The registry (artifacts.md) states the pairs;
# this script is the executable form of that table.
#
# An explicit environment variable always wins, so a caller can still point a
# check at a file in an unusual place. That override is the escape hatch
# verify-plan.sh already documented via PRD/UX/ADR.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OWNERSHIP_SH="$HERE/../../steering/references/ownership.sh"

REPO="${1:-}"
case "$REPO" in
  PRD|TECH|UX|ADR|CONTEXT|PLANDIR|ARCHIVES|OWNERSHIP) KEY=$REPO; REPO=. ;;
  "") KEY=""; REPO=. ;;
  *) KEY="${2:-}" ;;
esac

cd "$REPO" 2>/dev/null || { echo "resolve-paths: no such directory: $REPO" >&2; exit 2; }

# Ownership decides the tracked-vs-private split. PLAN_OWNERSHIP passes straight
# through to ownership.sh, which already treats it as an override.
if [ -x "$OWNERSHIP_SH" ]; then
  OWN=$("$OWNERSHIP_SH" . 2>/dev/null) || OWN=owned
else
  # Missing helper must not silently relocate tracked documents into .claude/:
  # 'owned' is the same default ownership.sh applies with no signal.
  OWN=owned
fi
[ "$OWN" = "foreign" ] || OWN=owned

# Private artifacts: same path either way, always gitignored.
PRD="${PRD:-.claude/project/prd.md}"
TECH="${TECH:-.claude/project/tech.md}"
PLANDIR="${PLANDIR:-.claude/plan}"
ARCHIVES="${ARCHIVES:-.claude/project/archives}"

# Tracked artifacts: the owned/foreign pairs from steering's ownership table.
if [ "$OWN" = "foreign" ]; then
  UX="${UX:-.claude/project/ux.md}"
  ADR="${ADR:-.claude/project/decisions}"
  CONTEXT="${CONTEXT:-.claude/project/context.md}"
else
  UX="${UX:-docs/ux.md}"
  ADR="${ADR:-docs/adr}"
  CONTEXT="${CONTEXT:-CONTEXT.md}"
fi

if [ -n "$KEY" ]; then
  eval "printf '%s\n' \"\$$KEY\""
  exit 0
fi

# Default output is eval-able, so a consumer adopts every path in one line:
#   eval "$(resolve-paths.sh)"
for k in OWNERSHIP PRD TECH UX ADR CONTEXT PLANDIR ARCHIVES; do
  case $k in OWNERSHIP) v=$OWN ;; *) eval "v=\$$k" ;; esac
  printf '%s=%s\n' "$k" "$v"
done
