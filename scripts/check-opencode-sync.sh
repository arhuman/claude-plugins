#!/bin/sh
# The committed opencode/ tree is generated from plugins/10x by
# gen-opencode.sh; a hand edit or a source change without regeneration
# makes the two drift silently, which this check turns into a CI failure.
# It also validates the bounds OpenCode itself enforces at load time
# (frontmatter parses, description length, agent id shape) on both the
# generated files and the source SKILL.md files the installer ships
# unmodified, and rejects em/en dashes in generated output: the dash hook
# only fires on live editor tool calls, never on generator output.
set -u

fail=0

# 1. Regeneration diff.
tmp=$(mktemp -d)
sh scripts/gen-opencode.sh "$tmp" >/dev/null || { echo "generator failed"; exit 1; }
if ! diff -r "$tmp" opencode >/dev/null 2>&1; then
  echo "opencode/ is stale: run 'sh scripts/gen-opencode.sh' and commit the result."
  diff -r "$tmp" opencode | head -40
  fail=1
fi
rm -rf "$tmp"

# 2. Bounds validation.
desc_len() {
  awk '
    NR==1 && $0=="---" {fm=1; next}
    fm && $0=="---" {exit}
    fm && index($0, "description: ") == 1 {
      sub(/^description: */, ""); gsub(/^'\''|'\''$/, ""); print length($0); exit
    }
  ' "$1"
}

for f in opencode/commands/*.md opencode/agents/*.md plugins/10x/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  len=$(desc_len "$f")
  if [ -z "$len" ] || [ "$len" -lt 1 ] || [ "$len" -gt 1024 ]; then
    echo "description missing or outside OpenCode's 1-1024 char bounds: $f (${len:-none})"
    fail=1
  fi
done

for f in opencode/agents/*.md; do
  stem=$(basename "$f" .md)
  case "$stem" in
    *[!a-z0-9-]*) echo "agent id not lowercase-alphanumeric-hyphen: $stem"; fail=1 ;;
  esac
  [ "${#stem}" -le 64 ] || { echo "agent id over 64 chars: $stem"; fail=1; }
done

if grep -rn '—\|–' opencode/ >/dev/null 2>&1; then
  echo "em or en dash in generated output:"
  grep -rn '—\|–' opencode/ | head -10
  fail=1
fi

# Frontmatter parse: real YAML parse when pyyaml is available (CI installs
# it), else the same colon-space grep fallback check-frontmatter-parses.sh
# uses, which catches the one construct that has actually broken before.
if python3 -c 'import yaml' 2>/dev/null; then
  python3 - <<'PY' || fail=1
import glob, sys, yaml
bad = 0
for f in glob.glob("opencode/*/*.md"):
    parts = open(f).read().split("---\n")
    try:
        yaml.safe_load(parts[1])
    except Exception as e:
        print(f"{f}: {e}")
        bad = 1
sys.exit(bad)
PY
else
  for f in opencode/commands/*.md opencode/agents/*.md; do
    if awk 'NR==1&&$0=="---"{fm=1;next} fm&&$0=="---"{exit} fm' "$f" \
      | grep -q "^[a-z]*: [^'\"].*: "; then
      echo "unquoted colon-space value in frontmatter (weaker fallback check): $f"
      fail=1
    fi
  done
fi

[ "$fail" -eq 0 ] && echo "opencode/ in sync and within OpenCode bounds."
exit $fail
