#!/bin/sh
# Prove claim.sh's compare-and-swap protocol against a toy plan file in a
# temporary directory: two simulated sessions race the same phase (exactly
# one wins), the loser moves to the next phase, renew refreshes the lease,
# verify with a stale token is refused, release returns the phase to todo,
# and an expired claim is reclaimable.
#
# Usage: sh scripts/test-claim.sh
set -u

REPO=$(git rev-parse --show-toplevel 2>/dev/null) || REPO=$(cd "$(dirname "$0")/.." && pwd)
CLAIM="$REPO/plugins/10x/skills/_shared/references/claim.sh"
WORK=$(mktemp -d) || exit 1
trap 'rm -rf "$WORK"' EXIT

fail=0
pass=0

# check <label> <expected-exit> <got-exit>
check() {
  label=$1 want=$2 got=$3
  if [ "$got" = "$want" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL $label: exit $got, want $want"
    fail=$((fail + 1))
  fi
}

# check_eq <label> <expected> <got>
check_eq() {
  label=$1 want=$2 got=$3
  if [ "$got" = "$want" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL $label: got '$got', want '$want'"
    fail=$((fail + 1))
  fi
}

new_plan() {
  cat > "$WORK/plan.md" <<'EOF'
# Plan: toy

Status legend: todo | backlog | doing | verified | blocked

## P1 - first phase
- Scope: none
- New deps: none
- Depends on: none
- Refs: none
- Accept: `true`
- Status: todo

## P2 - second phase
- Scope: none
- New deps: none
- Depends on: none
- Refs: none
- Accept: `true`
- Status: todo

## Log
EOF
}

field() {
  awk -v id="$2" -v key="$3" '
    /^## / { line=$0; sub(/^## /,"",line)
             h=line; sub(/[ \t]+-[ \t]+.*$/,"",h); cur=(h==id); next }
    cur && $0 ~ "^- " key ":" { sub("^- " key ":[ \t]*","");
                                sub(/[ \t]+$/,""); print; exit }
  ' "$1"
}

# --- 1. two sessions race the same phase: exactly one wins --------------------
new_plan
tA=$("$CLAIM" acquire "$WORK/plan.md" P1 sessionA 2>/dev/null)
rcA=$?
tB=$("$CLAIM" acquire "$WORK/plan.md" P1 sessionB 2>/dev/null)
rcB=$?
if [ "$rcA" = 0 ] && [ "$rcB" != 0 ]; then
  winner=A
elif [ "$rcB" = 0 ] && [ "$rcA" != 0 ]; then
  winner=B
else
  winner=neither
fi
check_eq "race: exactly one of A/B wins" "one" "$([ "$winner" != neither ] && echo one || echo neither)"
status=$(field "$WORK/plan.md" P1 Status)
check_eq "race: P1 status is doing" doing "$status"

# --- 2. the loser acquires the next phase --------------------------------------
if [ "$winner" = A ]; then
  loser_session=sessionB
else
  loser_session=sessionA
fi
"$CLAIM" acquire "$WORK/plan.md" P2 "$loser_session" >/dev/null 2>&1
rcLoser=$?
check "loser acquires P2" 0 "$rcLoser"
status2=$(field "$WORK/plan.md" P2 Status)
check_eq "P2 status is doing" doing "$status2"

# --- 3. renew refreshes the lease stamp ----------------------------------------
if [ "$winner" = A ]; then token=$tA; else token=$tB; fi
held_before=$(field "$WORK/plan.md" P1 Claimed-by)
sleep 1
"$CLAIM" renew "$WORK/plan.md" P1 "$token" 2>/dev/null
rc_renew=$?
check "renew succeeds for the owner" 0 "$rc_renew"
held_after=$(field "$WORK/plan.md" P1 Claimed-by)
if [ "$held_before" != "$held_after" ]; then
  pass=$((pass + 1))
else
  echo "FAIL renew: Claimed-by stamp did not change"
  fail=$((fail + 1))
fi

# --- 4. verify with a stale (wrong) token is refused ---------------------------
"$CLAIM" verify "$WORK/plan.md" P1 "not-the-real-token" 2>/dev/null
rc_verify_bad=$?
check "verify refuses a wrong token" 1 "$rc_verify_bad"
"$CLAIM" verify "$WORK/plan.md" P1 "$token" 2>/dev/null
rc_verify_good=$?
check "verify accepts the real token" 0 "$rc_verify_good"

# --- 5. release returns the phase to todo --------------------------------------
"$CLAIM" release "$WORK/plan.md" P1 "$token" 2>/dev/null
rc_release=$?
check "release succeeds for the owner" 0 "$rc_release"
status_released=$(field "$WORK/plan.md" P1 Status)
check_eq "released P1 is todo" todo "$status_released"
claimed_released=$(field "$WORK/plan.md" P1 Claimed-by)
check_eq "released P1 has no Claimed-by" "" "$claimed_released"

# release with a token that is no longer valid (already released) is refused,
# not silently accepted: proves release itself goes through the same
# ownership check as verify, not a bare field write.
"$CLAIM" release "$WORK/plan.md" P1 "$token" 2>/dev/null
rc_release_again=$?
check "releasing an already-released phase is refused" 1 "$rc_release_again"

# --- 6. an expired claim is reclaimable ----------------------------------------
new_plan
t1=$("$CLAIM" acquire "$WORK/plan.md" P1 sessionC 2>/dev/null)
# Force the stale window to 0 minutes so the lease is immediately expired,
# without sleeping the test for real minutes.
sed -i.bak '1a\
Stale-claim-minutes: 0
' "$WORK/plan.md" && rm -f "$WORK/plan.md.bak"
sleep 1
t2=$("$CLAIM" acquire "$WORK/plan.md" P1 sessionD 2>/dev/null)
rc_reclaim=$?
check "expired claim is reclaimable" 0 "$rc_reclaim"
if [ -n "$t2" ] && [ "$t2" != "$t1" ]; then
  pass=$((pass + 1))
else
  echo "FAIL reclaim: new token was not issued"
  fail=$((fail + 1))
fi
# The old token must no longer verify: the reclaim actually transferred
# ownership, it did not just tolerate a second acquire.
"$CLAIM" verify "$WORK/plan.md" P1 "$t1" 2>/dev/null
rc_old_verify=$?
check "old token no longer verifies after reclaim" 1 "$rc_old_verify"

echo "done: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
