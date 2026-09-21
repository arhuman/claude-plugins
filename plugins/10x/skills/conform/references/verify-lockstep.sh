#!/bin/sh
# verify-lockstep.sh: fail when standard.yml and conform.sh have diverged.
#
# The runner is a generated view of the manifest, and the lockstep rule
# ("manifest first, then the runner, never one without the other") was held by
# prose alone until a real slip: v1.12 added makefile.test_split to the
# manifest and the runner kept executing 29 checks under a v1.11 banner,
# looking complete while never running the new probe. Nothing failed, which is
# exactly why this script exists.
#
# Checks, all mechanical:
#   1. standard_version (manifest) == STANDARD_VERSION (runner)
#   2. every non-manual manifest check id is in the runner, and vice versa
#      (manual: true checks are judgment calls the runner skips by design)
#   3. severities match per check id
#   4. probe strings match per check id, modulo whitespace
#
# On (4): ids and severities agreeing while the probes test different things is
# the drift this file existed to catch and did not. A runner probe may instead
# be a single shell function name (`_ui_layers`), which is how the long UI
# probes are factored; that indirection is accepted, but the function must
# actually be defined in the runner, because a probe calling a function that
# does not exist fails open and reports the check as passing.
#
# Usage:
#   verify-lockstep.sh              from anywhere inside the plugin repo
#   verify-lockstep.sh --self-test  perturb copies, prove each drift is caught
#
# LOCKSTEP_YML / LOCKSTEP_RUNNER override the two paths, which is how the
# self-test points the checks at perturbed copies.
set -u

here=$(cd "$(dirname "$0")" && pwd)
YML="${LOCKSTEP_YML:-$here/../../_shared/references/standard.yml}"
RUNNER="${LOCKSTEP_RUNNER:-$here/conform.sh}"

fail=0
err() { printf 'LOCKSTEP: %s\n' "$1" >&2; fail=1; }

run_checks() {
  yml=$1; runner=$2;  chk_rc=0

  vy=$(sed -n 's/^standard_version: *"\{0,1\}\([0-9.]*\)"\{0,1\}.*/\1/p' "$yml" | head -1)
  vr=$(sed -n 's/^STANDARD_VERSION="\([0-9.]*\)".*/\1/p' "$runner" | head -1)
  if [ "$vy" != "$vr" ]; then
    err "version: manifest says $vy, runner says $vr"; chk_rc=1
  fi

  # id<TAB>severity<TAB>probe for every non-manual manifest check.
  # The probe is single-quoted YAML on one line; strip the quotes and collapse
  # whitespace so only a real difference in what is executed can fail.
  ymap=$(awk '
    function flush() { if (id != "" && !manual) printf "%s\t%s\t%s\n", id, sev, probe }
    /^  - id: /   { flush(); id=$3; sev=""; probe=""; manual=0 }
    /^    severity: / { sev=$2 }
    /^    manual: true/ { manual=1 }
    /^    probe: / { probe=$0
                     sub(/^    probe: /, "", probe)
                     sub(/^'"'"'/, "", probe); sub(/'"'"'$/, "", probe)
                     gsub(/[ \t]+/, " ", probe) }
    END { flush() }
  ' "$yml" | sort)

  # id<TAB>severity<TAB>probe from the runner table. The row is
  # id|applies_to|severity|profile_override|probe, and the probe itself may
  # contain pipes, so take everything past the fourth field.
  rmap=$(awk -F'|' '/^[a-z_]+\.[a-z_]+\|/ {
    probe=$0
    for (i = 1; i <= 4; i++) sub(/^[^|]*\|/, "", probe)
    gsub(/[ \t]+/, " ", probe)
    printf "%s\t%s\t%s\n", $1, $3, probe
  }' "$runner" | sort)

  # portable two-way diff on ids
  y_ids=$(printf '%s\n' "$ymap" | cut -f1)
  r_ids=$(printf '%s\n' "$rmap" | cut -f1)
  for i in $y_ids; do
    printf '%s\n' "$r_ids" | grep -qxF "$i" || { err "check $i is in the manifest but not in the runner"; chk_rc=1; }
  done
  for i in $r_ids; do
    printf '%s\n' "$y_ids" | grep -qxF "$i" || { err "check $i is in the runner but not in the manifest"; chk_rc=1; }
  done

  # severity and probe per shared id
  for i in $y_ids; do
    printf '%s\n' "$r_ids" | grep -qxF "$i" || continue
    sy=$(printf '%s\n' "$ymap" | awk -F'\t' -v k="$i" '$1==k{print $2}')
    sr=$(printf '%s\n' "$rmap" | awk -F'\t' -v k="$i" '$1==k{print $2}')
    [ "$sy" = "$sr" ] || { err "check $i: severity $sy in the manifest, $sr in the runner"; chk_rc=1; }

    py=$(printf '%s\n' "$ymap" | awk -F'\t' -v k="$i" '$1==k{print $3}')
    pr=$(printf '%s\n' "$rmap" | awk -F'\t' -v k="$i" '$1==k{print $3}')
    [ "$py" = "$pr" ] && continue

    # A bare function name is the accepted factoring for a long probe, but the
    # function has to exist: an undefined one would make the check pass blindly.
    case "$pr" in
      _[a-z_]*)
        if ! grep -qE "^$pr\(\) *\{" "$runner"; then
          err "check $i: runner probe calls $pr, which the runner never defines"
          chk_rc=1
        fi
        continue ;;
    esac

    err "check $i: probe differs
       manifest: $py
       runner  : $pr"
    chk_rc=1
  done

  return $chk_rc
}

self_test() {
  t=$(mktemp -d); rc=0
  cp "$YML" "$t/s.yml"; cp "$RUNNER" "$t/c.sh"

  fail=0
  run_checks "$t/s.yml" "$t/c.sh" >/dev/null 2>&1 \
    || { echo "self-test FAIL: clean pair rejected"; rc=1; }

  sed 's/^standard_version: .*/standard_version: "9.9"/' "$YML" > "$t/s.yml"
  fail=0
  run_checks "$t/s.yml" "$t/c.sh" >/dev/null 2>&1 \
    && { echo "self-test FAIL: version drift missed"; rc=1; }

  cp "$YML" "$t/s.yml"
  grep -v '^makefile.test_split|' "$RUNNER" > "$t/c.sh"
  fail=0
  run_checks "$t/s.yml" "$t/c.sh" >/dev/null 2>&1 \
    && { echo "self-test FAIL: missing runner check missed"; rc=1; }

  cp "$RUNNER" "$t/c.sh"
  sed 's/^makefile.test_split|\([^|]*\)|P1|/makefile.test_split|\1|P2|/' "$RUNNER" > "$t/c.sh"
  fail=0
  run_checks "$t/s.yml" "$t/c.sh" >/dev/null 2>&1 \
    && { echo "self-test FAIL: severity drift missed"; rc=1; }

  # a probe that silently tests something else: ids and severities still agree
  sed 's/^ci\.audit|\([^|]*\)|\([^|]*\)|\([^|]*\)|.*/ci.audit|\1|\2|\3|true/' "$RUNNER" > "$t/c.sh"
  fail=0
  run_checks "$t/s.yml" "$t/c.sh" >/dev/null 2>&1 \
    && { echo "self-test FAIL: probe drift missed"; rc=1; }

  # indirection through a function the runner never defines
  sed 's/^ci\.audit|\([^|]*\)|\([^|]*\)|\([^|]*\)|.*/ci.audit|\1|\2|\3|_never_defined/' "$RUNNER" > "$t/c.sh"
  fail=0
  run_checks "$t/s.yml" "$t/c.sh" >/dev/null 2>&1 \
    && { echo "self-test FAIL: undefined probe function missed"; rc=1; }

  # the accepted factoring must still pass: _ui_layers is defined in the runner
  cp "$RUNNER" "$t/c.sh"
  fail=0
  run_checks "$t/s.yml" "$t/c.sh" >/dev/null 2>&1 \
    || { echo "self-test FAIL: accepted function indirection rejected"; rc=1; }

  rm -rf "$t"
  [ $rc -eq 0 ] && echo "self-test PASS (clean pair, version, missing check, severity, probe, undefined fn)"
  return $rc
}

case "${1:-}" in
  --self-test) self_test; exit $? ;;
esac

run_checks "$YML" "$RUNNER"
[ "$fail" -eq 0 ] && echo "LOCKSTEP: standard.yml and conform.sh agree (v$(sed -n 's/^STANDARD_VERSION="\([0-9.]*\)".*/\1/p' "$RUNNER"))"
exit "$fail"
