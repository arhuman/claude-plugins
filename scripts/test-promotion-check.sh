#!/bin/sh
# Prove promotion-check.sh against throwaway Go modules wired with local
# replace directives (no network): a module reached only through a dependency
# passes as indirect, a test that imports it directly while go.mod marks it
# indirect is reported, and a go failure exits 2 rather than reading as a pass.
#
# Usage: sh scripts/test-promotion-check.sh
set -u

if ! command -v go >/dev/null 2>&1; then
  echo "test-promotion-check: go not installed, skipped"
  exit 0
fi

REPO=$(cd "$(dirname "$0")/.." && pwd)
CHECK="$REPO/plugins/10x/skills/loop/references/promotion-check.sh"
WORK=$(mktemp -d) || exit 1
trap 'rm -rf "$WORK"' EXIT

export GOWORK=off GOPROXY=off GOFLAGS=-mod=mod GOTOOLCHAIN=local
# GOFLAGS=-mod=mod proves the check pins -mod=readonly: without it go list
# rewrites a stale // indirect marker for a non-test import and hides it.

fail=0
pass=0

# check <label> <expected-exit> <got-exit> <expected-output> <got-output>
check() {
  if [ "$3" = "$2" ] && [ "$5" = "$4" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL $1: exit $3 output '$5', want exit $2 output '$4'"
    fail=$((fail + 1))
  fi
}

mkdir -p "$WORK/c" "$WORK/b" "$WORK/a"
printf 'module example.com/c\n\ngo 1.21\n' > "$WORK/c/go.mod"
printf 'package c\n\nconst Name = "c"\n' > "$WORK/c/c.go"

cat > "$WORK/b/go.mod" <<'EOF'
module example.com/b

go 1.21

require example.com/c v0.0.0

replace example.com/c => ../c
EOF
printf 'package b\n\nimport "example.com/c"\n\nconst Name = "b" + c.Name\n' > "$WORK/b/b.go"

cat > "$WORK/a/go.mod" <<'EOF'
module example.com/a

go 1.21

require (
	example.com/b v0.0.0
	example.com/c v0.0.0 // indirect
)

replace (
	example.com/b => ../b
	example.com/c => ../c
)
EOF
printf 'package a\n\nimport "example.com/b"\n\nconst Name = b.Name\n' > "$WORK/a/a.go"

out=$(cd "$WORK/a" && sh "$CHECK" 2>&1); rc=$?
check "transitive-only module passes" 0 "$rc" "" "$out"

printf 'package a\n\nimport (\n\t"testing"\n\n\t"example.com/c"\n)\n\nfunc TestC(t *testing.T) { _ = c.Name }\n' > "$WORK/a/a_test.go"
out=$(cd "$WORK/a" && sh "$CHECK" 2>&1); rc=$?
check "direct test import of an indirect module is reported (require block)" 1 "$rc" "example.com/c" "$out"

cat > "$WORK/a/go.mod" <<'EOF2'
module example.com/a

go 1.21

require example.com/b v0.0.0

require example.com/c v0.0.0 // indirect

replace (
	example.com/b => ../b
	example.com/c => ../c
)
EOF2
out=$(cd "$WORK/a" && sh "$CHECK" 2>&1); rc=$?
check "single-line indirect require is reported" 1 "$rc" "example.com/c" "$out"

printf 'package a\n\nimport "example.com/c"\n\nconst Direct = c.Name\n' > "$WORK/a/direct.go"
out=$(cd "$WORK/a" && sh "$CHECK" 2>&1); rc=$?
check "direct code import of an indirect module is reported, go.mod untouched" 1 "$rc" "example.com/c" "$out"
grep -q 'example.com/c v0.0.0 // indirect' "$WORK/a/go.mod"; rc=$?
check "the check leaves go.mod as it found it" 0 "$rc" "" ""

sed 's|example.com/c v0.0.0 // indirect|example.com/c v0.0.0|' "$WORK/a/go.mod" > "$WORK/a/go.mod.new" &&
  mv "$WORK/a/go.mod.new" "$WORK/a/go.mod"
out=$(cd "$WORK/a" && sh "$CHECK" 2>&1); rc=$?
check "declared direct requirement passes" 0 "$rc" "" "$out"

printf 'package a\n\nimport "example.com/missing"\n\nvar _ = missing.Name\n' > "$WORK/a/broken.go"
(cd "$WORK/a" && sh "$CHECK" >/dev/null 2>&1); rc=$?
check "unresolvable import exits 2" 2 "$rc" "" ""

echo "test-promotion-check: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
