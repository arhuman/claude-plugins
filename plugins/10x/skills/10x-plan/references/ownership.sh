#!/bin/sh
# ownership.sh - decide whether this repo is ours to write steering documents into.
# Usage: ownership.sh [repo-path]        (default: .)
# Prints "owned" or "foreign" on stdout, plus the reason on stderr. Always exits 0.
#
# Why this exists: docs/ux.md, CONTEXT.md, CONTRIBUTING.md and docs/adr/ are
# TRACKED. On a fork or a third-party checkout they would land in a pull request,
# proposing methodology files the maintainer never asked for, inside a change
# that was supposed to fix a bug. That is not clutter, it is a social mistake,
# and the fix is to never write them there in the first place.
#
# Resolution order, first hit wins:
#   1. PLAN_OWNERSHIP=owned|foreign          explicit override, always obeyed
#   2. 10x-profile: in CLAUDE.md / AGENTS.md the repo already runs this method
#   3. git remote origin is a fork           GitHub says so
#   4. foreign-governance heuristics         CODE_OF_CONDUCT.md, upstream .github/
#   5. default: owned                        a local repo with no signal is yours
set -eu

cd "${1:-.}" 2>/dev/null || { echo owned; exit 0; }

say() { printf 'ownership: %s\n' "$1" >&2; }

# 1. Explicit override.
case "${PLAN_OWNERSHIP:-}" in
  owned)   say "PLAN_OWNERSHIP=owned"; echo owned; exit 0 ;;
  foreign) say "PLAN_OWNERSHIP=foreign"; echo foreign; exit 0 ;;
  "") ;;
  *) say "unknown PLAN_OWNERSHIP '${PLAN_OWNERSHIP}', ignored" ;;
esac

# 2. The repo already declares a 10x profile: it runs this methodology, so its
#    steering documents belong in it. This is the same key conform.sh reads.
if grep -hsqE '10x-profile:[[:space:]]*[a-z]+' CLAUDE.md AGENTS.md 2>/dev/null; then
  say "CLAUDE.md declares a 10x-profile, repo already runs this methodology"
  echo owned; exit 0
fi

# 3. A fork is never ours to shape, whoever owns the fork.
if command -v gh >/dev/null 2>&1; then
  isfork=$(gh repo view --json isFork -q .isFork 2>/dev/null || true)
  if [ "$isfork" = "true" ]; then
    parent=$(gh repo view --json parent -q '.parent.nameWithOwner' 2>/dev/null || true)
    say "fork of ${parent:-an upstream repo}"
    echo foreign; exit 0
  fi
fi

# 4. Governance files someone else wrote. A CODE_OF_CONDUCT.md or an issue
#    template set is the signature of a project with its own community process:
#    adding CONTRIBUTING.md or an ADR tree to it is presumptuous.
for f in CODE_OF_CONDUCT.md .github/ISSUE_TEMPLATE .github/PULL_REQUEST_TEMPLATE.md; do
  if [ -e "$f" ]; then
    say "$f exists, this project carries its own governance"
    echo foreign; exit 0
  fi
done

# 5. No signal: a repo on your disk with no upstream governance is yours.
say "no foreign-ownership signal"
echo owned
