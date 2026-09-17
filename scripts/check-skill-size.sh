#!/bin/sh
# Every SKILL.md stays under 500 lines.
#
# A SKILL.md is loaded whole into context every time the skill triggers, so
# its size is a per-invocation tax. The Agent Skills convention (and the cap
# ironloop enforces on itself) is 500 lines: past that, detail belongs in
# references/ files loaded on demand, not in the entry point.
set -u
limit=500
fail=0
for skill in plugins/*/skills/*/SKILL.md; do
  lines=$(wc -l < "$skill")
  if [ "$lines" -ge "$limit" ]; then
    echo "TOO LONG: $skill has $lines lines (limit $limit); move detail to references/"
    fail=1
  fi
done
exit $fail
