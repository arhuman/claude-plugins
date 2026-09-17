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
#
# Usage:
#   verify-lockstep.sh              from anywhere inside the plugin repo
#   verify-lockstep.sh --self-test  perturb copies, prove each drift is caught
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

  # id<TAB>severity for every non-manual manifest check
  ymap=$(awk '
    /^  - id: /   { if (id != "" && !manual) printf "%s\t%s\n", id, sev
                    id=$3; sev=""; manual=0 }
    /^    severity: / { sev=$2 }
    /^    manual: true/ { manual=1 }
    END { if (id != "" && !manual) printf "%s\t%s\n", id, sev }
  ' "$yml" | sort)

  # id<TAB>severity from the runner table (field 1 and 3 of pipe-separated rows)
  rmap=$(awk -F'|' '/^[a-z_]+\.[a-z_]+\|/ { printf "%s\t%s\n", $1, $3 }' "$runner" | sort)

  # portable two-way diff on ids
  y_ids=$(printf '%s\n' "$ymap" | cut -f1)
  r_ids=$(printf '%s\n' "$rmap" | cut -f1)
  for i in $y_ids; do
    printf '%s\n' "$r_ids" | grep -qxF "$i" || { err "check $i is in the manifest but not in the runner"; chk_rc=1; }
  done
  for i in $r_ids; do
    printf '%s\n' "$y_ids" | grep -qxF "$i" || { err "check $i is in the runner but not in the manifest"; chk_rc=1; }
  done

  # severity per shared id
  for i in $y_ids; do
    printf '%s\n' "$r_ids" | grep -qxF "$i" || continue
    sy=$(printf '%s\n' "$ymap" | awk -F'\t' -v k="$i" '$1==k{print $2}')
    sr=$(printf '%s\n' "$rmap" | awk -F'\t' -v k="$i" '$1==k{print $2}')
    [ "$sy" = "$sr" ] || { err "check $i: severity $sy in the manifest, $sr in the runner"; chk_rc=1; }
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

  rm -rf "$t"
  [ $rc -eq 0 ] && echo "self-test PASS (clean pair, version, missing check, severity)"
  return $rc
}

case "${1:-}" in
  --self-test) self_test; exit $? ;;
esac

run_checks "$YML" "$RUNNER"
[ "$fail" -eq 0 ] && echo "LOCKSTEP: standard.yml and conform.sh agree (v$(sed -n 's/^STANDARD_VERSION="\([0-9.]*\)".*/\1/p' "$RUNNER"))"
exit "$fail"
