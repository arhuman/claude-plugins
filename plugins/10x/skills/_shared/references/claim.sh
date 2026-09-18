#!/bin/sh
# claim.sh - compare-and-swap phase claiming for a plan file.
# Usage:
#   claim.sh acquire <plan> <phase-id> [session]   -> prints the claim token, exit 0
#   claim.sh renew   <plan> <phase-id> <token>     -> refreshes the lease stamp
#   claim.sh verify  <plan> <phase-id> <token>     -> exit 0 if still ours
#   claim.sh release <plan> <phase-id> <token>     -> back to todo, clears the claim
#
# Exit codes: 0 ok, 1 lost the race or not the owner, 2 usage/environment error.
#
# Why this exists: "write the claim, re-read it, proceed if it survived" does not
# provide exclusivity. Two sessions interleave as
#   A reads todo / B reads todo / A writes claim A / A re-reads A, proceeds
#   / B writes claim B / B re-reads B, proceeds
# and both implement the same phase. Re-reading confirms only that nobody
# overwrote you *yet*; it is not a compare-and-swap. The fix is to make the
# whole read-modify-write atomic against other claimers.
#
# Two mechanisms, two distinct failure modes, neither substituting for the other
# (the same split concurrency.md draws between claims and workspaces):
#
#   - A mutex (mkdir, atomic on POSIX and on macOS/Linux alike) serializes the
#     read-modify-write so two claimers cannot both observe `todo`.
#   - A per-claim random token, written into Claimed-by and required by renew,
#     verify and release, proves *which* session holds the phase. Without it a
#     session whose lease expired and was reclaimed can still mark the phase
#     verified, closing work that a different session now owns.
#
# The mutex is held for the duration of a field rewrite (milliseconds), never
# across implementation or the gate. The lease, not the mutex, is what spans the
# turn; see plan-format.md, Claiming a phase.
set -eu

usage() { echo "usage: claim.sh acquire|renew|verify|release <plan> <phase-id> [token]" >&2; exit 2; }

ACTION="${1:-}"; PLAN="${2:-}"; PHASE="${3:-}"; ARG="${4:-}"
[ -n "$ACTION" ] && [ -n "$PLAN" ] && [ -n "$PHASE" ] || usage
[ -f "$PLAN" ] || { echo "claim: no such plan file: $PLAN" >&2; exit 2; }

LOCK="$PLAN.claimlock"
STALE_DEFAULT=120

now()   { date +%s; }
stamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Stale window in minutes: a `Stale-claim-minutes: <n>` line under the plan
# title overrides the default, per plan-format.md.
stale_minutes() {
  m=$(sed -n 's/^Stale-claim-minutes:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$PLAN" | head -1)
  [ -n "$m" ] && echo "$m" || echo "$STALE_DEFAULT"
}

# A claim token: random, opaque, unique per acquire. $$ alone repeats across
# machines and after PID reuse, so it is only one ingredient.
mktoken() {
  rnd=$(od -An -N6 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n') || rnd=""
  [ -n "$rnd" ] || rnd=$(awk 'BEGIN{srand();printf "%06x", rand()*16777215}')
  printf '%s-%s' "$$" "$rnd"
}

# --- mutex -------------------------------------------------------------------
# mkdir is the portable atomic test-and-set: it fails if the directory exists,
# in one syscall, with no window between the test and the set. A lock older
# than 60s belongs to a killed process; break it rather than deadlocking the
# plan forever. 60s is far above any field rewrite and far below the lease.
lock() {
  i=0
  while ! mkdir "$LOCK" 2>/dev/null; do
    if [ -d "$LOCK" ]; then
      age=$(( $(now) - $(lock_mtime) ))
      if [ "$age" -gt 60 ]; then
        rmdir "$LOCK" 2>/dev/null || true
        continue
      fi
    fi
    i=$((i + 1))
    [ "$i" -gt 50 ] && { echo "claim: could not acquire $LOCK after 50 tries" >&2; exit 2; }
    sleep 0.1 2>/dev/null || sleep 1
  done
  trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT INT TERM
}

lock_mtime() {
  # BSD stat (macOS) and GNU stat (Linux) disagree on flags; try both.
  stat -f %m "$LOCK" 2>/dev/null || stat -c %Y "$LOCK" 2>/dev/null || now
}

unlock() { rmdir "$LOCK" 2>/dev/null || true; trap - EXIT INT TERM; }

# --- phase field access ------------------------------------------------------
# A phase heading is "## <id> - <goal>"; its fields are the "- Key: value" lines
# up to the next "## ". Same shape verify-plan.sh parses.
field() {
  awk -v id="$PHASE" -v key="$2" '
    /^## / { line=$0; sub(/^## /,"",line)
             h=line; sub(/[ \t]+-[ \t]+.*$/,"",h); cur=(h==id); next }
    cur && $0 ~ "^- " key ":" { sub("^- " key ":[ \t]*","");
                                sub(/[ \t]+$/,""); print; exit }
  ' "$1"
}

phase_exists() {
  awk -v id="$PHASE" '
    /^## / { line=$0; sub(/^## /,"",line)
             h=line; sub(/[ \t]+-[ \t]+.*$/,"",h)
             if (h==id) { found=1; exit } }
    END { exit !found }
  ' "$PLAN"
}

# Set (or insert) a field on the phase. Writes to a temp file in the same
# directory and renames: a reader never observes a half-written plan, and the
# rename is atomic on the same filesystem. Deleting and rewriting in place would
# expose exactly the truncated-file window this avoids.
#
# An inserted field goes immediately after the phase's last "- Key:" line, not
# at the next heading: the blank line before the next "## " is part of the
# file's shape, and appending past it detaches the field from its phase and
# reads as a stray bullet.
set_field() {
  key=$1; val=$2
  tmp=$(mktemp "$PLAN.XXXXXX")
  awk -v id="$PHASE" -v key="$key" -v val="$val" '
    # Buffer trailing non-field lines (blank separators, prose) so a pending
    # insert can be placed before them rather than after.
    function drain(  i) { for (i = 1; i <= nheld; i++) print heldline[i]; nheld = 0 }
    function insert() { if (val != "") print "- " key ": " val; done_field = 1 }
    /^## / {
      if (cur && !done_field) insert()
      drain()
      line=$0; sub(/^## /,"",line)
      h=line; sub(/[ \t]+-[ \t]+.*$/,"",h)
      cur=(h==id); done_field=0
      print; next
    }
    cur && $0 ~ "^- " key ":" {
      drain()
      if (val != "") print "- " key ": " val
      done_field=1; next
    }
    cur && /^- [A-Za-z][A-Za-z ]*:/ { drain(); print; next }
    cur { heldline[++nheld] = $0; next }
    { print }
    END { if (cur && !done_field) insert(); drain() }
  ' "$PLAN" > "$tmp"
  mv "$tmp" "$PLAN"
}

clear_field() { set_field "$1" ""; }

# Seconds since a Claimed-by stamp of the form <session>@<iso8601>.
claim_age() {
  ts=${1##*@}
  [ -n "$ts" ] || { echo 999999999; return; }
  epoch=$(date -u -j -f %Y-%m-%dT%H:%M:%SZ "$ts" +%s 2>/dev/null \
       || date -u -d "$ts" +%s 2>/dev/null || echo 0)
  [ "$epoch" -gt 0 ] || { echo 999999999; return; }
  echo $(( $(now) - epoch ))
}

token_of() { echo "${1%%@*}" | sed -n 's/.*#\(.*\)$/\1/p'; }

case "$ACTION" in
  acquire)
    session=${ARG:-sh$$}
    lock
    phase_exists || { unlock; echo "claim: no phase '$PHASE' in $PLAN" >&2; exit 2; }
    status=$(field "$PLAN" Status)
    held=$(field "$PLAN" Claimed-by)
    case "$status" in
      todo) ;;
      doing)
        # Reclaimable only once the lease has expired. This is the branch the
        # re-read protocol got wrong: under the mutex, exactly one session can
        # be here at a time, so the decision cannot be made twice.
        age=$(claim_age "$held")
        limit=$(( $(stale_minutes) * 60 ))
        if [ -z "$held" ] || [ "$age" -gt "$limit" ]; then
          echo "claim: reclaiming stale $PHASE (held by ${held:-nobody}, ${age}s old)" >&2
        else
          unlock; echo "claim: $PHASE is held by $held" >&2; exit 1
        fi
        ;;
      *) unlock; echo "claim: $PHASE is '$status', not claimable" >&2; exit 1 ;;
    esac
    token=$(mktoken)
    set_field Status doing
    set_field Claimed-by "$session#$token@$(stamp)"
    unlock
    echo "$token"
    ;;

  renew)
    [ -n "$ARG" ] || usage
    lock
    held=$(field "$PLAN" Claimed-by)
    if [ "$(token_of "$held")" != "$ARG" ]; then
      unlock; echo "claim: $PHASE is no longer ours (now: ${held:-unclaimed})" >&2; exit 1
    fi
    set_field Claimed-by "${held%@*}@$(stamp)"
    unlock
    ;;

  verify)
    [ -n "$ARG" ] || usage
    held=$(field "$PLAN" Claimed-by)
    [ "$(token_of "$held")" = "$ARG" ] || {
      echo "claim: $PHASE is no longer ours (now: ${held:-unclaimed})" >&2; exit 1; }
    ;;

  release)
    [ -n "$ARG" ] || usage
    lock
    held=$(field "$PLAN" Claimed-by)
    if [ "$(token_of "$held")" != "$ARG" ]; then
      unlock; echo "claim: $PHASE is no longer ours (now: ${held:-unclaimed})" >&2; exit 1
    fi
    set_field Status todo
    clear_field Claimed-by
    unlock
    ;;

  *) usage ;;
esac
