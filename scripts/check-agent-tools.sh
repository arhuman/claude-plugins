#!/bin/sh
# Analysis agents must not be able to edit the code they analyse.
#
# A subagent asked "is this finding real?" reaches for the most direct answer:
# change the code and see what happens. It then reports a confirmed finding and
# the mutation stays in a working tree whose owner is reading a report, not
# watching a diff. Reviewers and auditors therefore declare an explicit `tools:`
# allowlist with no Edit and no NotebookEdit.
#
# Write is deliberately still allowed: these agents' whole deliverable is a
# report (review directory, scores.json, findings.csv, conform-<repo>.md).
# Denying Write would not harden them, it would break them. The line that
# matters is source mutation, not filesystem access.
#
# Inverted on purpose: this flags any listed agent that does NOT carry the
# restriction, rather than checking a list of known-good ones. Counting
# known-good agents passes a new agent that inherits every tool by default,
# which is the failure this exists to catch. Omitting `tools:` entirely grants
# everything, so a missing line is a failure, not a skip.
#
# Adding an analysis agent means adding it to ANALYSIS_AGENTS below. An agent
# that legitimately edits code (coder, fixer, docker, documentation) does not
# belong in this list.
set -u

# agent file basename, one per line
ANALYSIS_AGENTS='review-agent
conform-agent'

fail=0

for name in $ANALYSIS_AGENTS; do
  found=0
  for f in plugins/*/agents/"$name".md; do
    [ -f "$f" ] || continue
    found=1

    # Frontmatter only: a `tools:` written in prose further down the file is not
    # a grant and must not satisfy this check.
    tools=$(awk '
      NR == 1 && $0 == "---" { in_fm = 1; next }
      in_fm && $0 == "---"   { exit }
      in_fm && /^tools:/     { sub(/^tools:[[:space:]]*/, ""); print; exit }
    ' "$f")

    if [ -z "$tools" ]; then
      echo "FAIL: $f declares no 'tools:' line."
      echo "      An agent with no tools line inherits every tool, Edit included."
      fail=1
      continue
    fi

    for banned in Edit NotebookEdit; do
      # Comma/space delimited match so MultiEdit or a future EditFoo does not
      # collide, and so Edit inside a longer name is not a false positive.
      if printf '%s' "$tools" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
           | grep -qx "$banned"; then
        echo "FAIL: $f grants $banned."
        echo "      Analysis agents must not mutate the source they analyse."
        fail=1
      fi
    done
  done

  if [ "$found" -eq 0 ]; then
    echo "FAIL: no agent file found for '$name' under plugins/*/agents/."
    echo "      A check that silently passes because its target moved is worse than none."
    echo "      Update ANALYSIS_AGENTS in scripts/check-agent-tools.sh if it was renamed."
    fail=1
  fi
done

if [ "$fail" -eq 1 ]; then
  echo
  echo "Give the agent an explicit 'tools:' allowlist without Edit/NotebookEdit."
  echo "Keep Write if it authors a report; add Task if it dispatches other agents."
  exit 1
fi

echo "Analysis agents carry no source-mutation tools."
exit 0
