#!/bin/sh
# Prove `make tokens` separates its two non-green outcomes: a budget overflow
# must fail, a missing tiktoken must SKIP and pass. Runs the real Makefile
# target against a temporary copy of the skills and budget, so the repo's own
# budget file is never edited.
#
# Usage: sh scripts/test-token-gate.sh
set -u

REPO=$(git rev-parse --show-toplevel 2>/dev/null) || REPO=$(cd "$(dirname "$0")/.." && pwd)
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

# check_out <label> <pattern> <file>: the run's output must match <pattern>.
check_out() {
  if grep -q "$2" "$3"; then
    pass=$((pass + 1))
  else
    echo "FAIL $1: output lacks '$2'"
    sed 's/^/  | /' "$3" | tail -5
    fail=$((fail + 1))
  fi
}

# A Python that can import tiktoken is a precondition, not a case: without
# one, every case below would SKIP and the suite would prove nothing.
VENV_BIN="$REPO/.venv/bin"
if [ -x "$VENV_BIN/python3" ] && "$VENV_BIN/python3" -c 'import tiktoken' 2>/dev/null; then
  RUN_PATH="$VENV_BIN:$PATH"
elif python3 -c 'import tiktoken' 2>/dev/null; then
  RUN_PATH=$PATH
else
  echo "FAIL precondition: no python3 imports tiktoken; run make tools"
  exit 1
fi

mkdir -p "$WORK/repo/scripts" "$WORK/repo/plugins/10x"
cp "$REPO/Makefile" "$WORK/repo/"
cp "$REPO/scripts/check-skill-tokens.py" "$REPO/scripts/skill-token-budget.json" "$WORK/repo/scripts/"
cp -R "$REPO/plugins/10x/skills" "$WORK/repo/plugins/10x/"

# tokens <outfile> [extra env assignments...]
tokens() {
  out=$1
  shift
  (cd "$WORK/repo" && env PATH="$RUN_PATH" "$@" make --no-print-directory tokens) > "$out" 2>&1
}

tokens "$WORK/within.out"
check "within budget exits 0" 0 $?
check_out "within budget runs the check" 'limit' "$WORK/within.out"
if grep -q 'SKIP' "$WORK/within.out"; then
  echo "FAIL within budget: printed SKIP although tiktoken imports"
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# Shrink the baseline so the current tree exceeds its limit.
PATH="$RUN_PATH" python3 - "$WORK/repo/scripts/skill-token-budget.json" <<'PY'
import json, sys
path = sys.argv[1]
doc = json.load(open(path, encoding="utf-8"))
doc["baseline"]["totals"]["entry"] = 1000
open(path, "w", encoding="utf-8").write(json.dumps(doc))
PY
tokens "$WORK/overflow.out"
rc=$?
if [ "$rc" -ne 0 ]; then pass=$((pass + 1)); else echo "FAIL overflow: exit 0, want non-zero"; fail=$((fail + 1)); fi
check_out "overflow names the surface" 'FAIL: entry exceeds' "$WORK/overflow.out"

# A stub module shadows the real tiktoken, so the import fails exactly as it
# does on a machine without it. The overflowing budget stays in place: an
# absent tokenizer must still SKIP, it never measures anything.
mkdir -p "$WORK/stub"
echo 'raise ImportError("stub: tiktoken absent")' > "$WORK/stub/tiktoken.py"
tokens "$WORK/absent.out" PYTHONPATH="$WORK/stub"
check "absent tiktoken exits 0" 0 $?
check_out "absent tiktoken prints SKIP" 'SKIP token budget' "$WORK/absent.out"

echo "token-gate: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
