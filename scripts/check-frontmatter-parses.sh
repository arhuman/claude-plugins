#!/bin/sh
# Every SKILL.md / command / agent frontmatter block must parse as YAML.
#
# This failed silently across nine files for months. The cause each time was an
# unquoted description containing ": " -- as in "(GORM, drivers): use lang-go".
# YAML reads that colon-space as a key separator, the block fails to parse, and
# the loader drops *every* field: name, description, model. The skill then has
# no description to match on, so it stops triggering, and nothing anywhere says
# so. `claude plugin validate --strict` catches it, but that needs the CLI
# installed and was only ever run in CI, where it had been red long enough to
# stop being read.
#
# Quote the value if it contains ": " (single quotes, doubling any internal
# single quote) rather than rewording it -- the description is matching text,
# and reflowing it to dodge a colon changes what the skill triggers on.
set -u

# Prefer python3 for a real YAML parse; fall back to a targeted grep for the
# one construct that has actually broken, so the check still says something
# useful on a runner without python.
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
  python3 - "$@" <<'PY'
import glob, sys, yaml

bad = 0
pats = ('plugins/*/skills/*/SKILL.md', 'plugins/*/commands/*.md', 'plugins/*/agents/*.md')
for pat in pats:
    for f in sorted(glob.glob(pat)):
        text = open(f, encoding='utf-8').read()
        if not text.startswith('---'):
            continue
        block = text.split('---')[1]
        try:
            meta = yaml.safe_load(block)
        except Exception as exc:
            print("FAIL: %s" % f)
            print("      frontmatter does not parse: %s" % str(exc).split('\n')[0])
            bad = 1
            continue
        if not isinstance(meta, dict) or 'description' not in meta:
            print("FAIL: %s" % f)
            print("      frontmatter parsed but carries no description.")
            bad = 1

if bad:
    print()
    print('Quote the offending value: description: \'...text with: a colon...\'')
    sys.exit(1)
print("All frontmatter blocks parse and carry a description.")
PY
  exit $?
fi

echo "python3+pyyaml unavailable; falling back to the colon-space grep." >&2
fail=0
for f in plugins/*/skills/*/SKILL.md plugins/*/commands/*.md plugins/*/agents/*.md; do
  [ -f "$f" ] || continue
  hit=$(awk '
    NR == 1 && $0 == "---" { in_fm = 1; next }
    in_fm && $0 == "---"   { exit }
    in_fm && /^[a-z-]+:/ {
      line = $0
      sub(/^[a-z-]+:[[:space:]]*/, "", line)
      # already quoted is fine
      if (line ~ /^["\047]/) next
      if (line ~ /: /) { printf "%d: %s\n", NR, $0 }
    }
  ' "$f")
  if [ -n "$hit" ]; then
    echo "FAIL: $f"
    printf '%s\n' "$hit" | sed 's/^/      /'
    fail=1
  fi
done

if [ "$fail" -eq 1 ]; then
  echo
  echo "An unquoted value containing \": \" parses as a mapping and drops the block."
  echo "Quote it: description: '...text with: a colon...'"
  exit 1
fi

echo "No unquoted colon-space values in frontmatter."
exit 0
