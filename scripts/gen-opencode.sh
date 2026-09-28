#!/bin/sh
# Generate the OpenCode-facing tree (commands and agents) from the Claude
# Code sources in plugins/10x/. Skills are NOT generated: every SKILL.md is
# already OpenCode-valid and install-opencode.sh symlinks them from source.
#
# Usage: sh scripts/gen-opencode.sh [output-dir]   (default: opencode)
#
# The output is committed; check-opencode-sync.sh regenerates into a temp
# dir and diffs, so hand-edits to opencode/ fail CI. Transformation rules
# live in the dual-consumption plan; the load-bearing ones:
# - command filenames gain a 10x- prefix (OpenCode has no plugin namespace),
#   the stem is otherwise kept verbatim so names match across both tools;
# - the model tier is NOT emitted: an OpenCode agent file's model: overrides
#   opencode.json, so a pinned id here could never be changed by a user.
#   install-opencode.sh --models binds tier to id in opencode.json instead,
#   from scripts/opencode-models.json and the user's own override;
# - path references into the plugin tree are rewritten to the one location
#   the installer guarantees: ~/.config/opencode/skills/.
set -u

SRC=plugins/10x
OUT=${1:-opencode}

# Print a frontmatter field's line from the first --- block only.
fm_line() {
  awk -v key="$2" '
    NR==1 && $0=="---" {fm=1; next}
    fm && $0=="---" {exit}
    fm && index($0, key ": ") == 1 {print; exit}
  ' "$1"
}

# Print everything after the closing --- of the frontmatter.
body_of() {
  awk 'c>=2{print; next} /^---$/{c++}' "$1"
}

# Build the MCP tool id substitutions from the reference table, so the mapping
# lives in one place a reader can find. Rows look like:
#   | `mcp__pal__debug` | `pal_debug` | coder-agent |
# A host names MCP tools itself, so an id written for Claude Code names nothing
# under OpenCode: the call fails even with the server configured.
TOOL_TABLE=$SRC/skills/_shared/references/tool-names.md
tool_id_script=$(
  sed -n 's/^| `\(mcp__[A-Za-z0-9_]*\)` *| `\([A-Za-z0-9_]*\)` *|.*/s,\1,\2,g/p' "$TOOL_TABLE"
)
[ -n "$tool_id_script" ] || { echo "no tool id rows found in $TOOL_TABLE" >&2; exit 1; }

# Rewrite MCP tool ids to the host's naming scheme.
rewrite_tool_ids() {
  sed "$tool_id_script"
}

# Rewrite plugin-tree path references to the installed skills location.
# Anchored on a preceding backtick, space, or paren plus a known skills/
# child prefix, so prose mentioning "skills" is never touched.
rewrite_paths() {
  # -E: BSD sed has no alternation in basic regex and fails silently there.
  sed -E \
    -e 's,`\.\./skills/,`~/.config/opencode/skills/,g' \
    -e 's,`\.\./_shared/,`~/.config/opencode/skills/_shared/,g' \
    -e 's,([ `(])skills/(10x-|lang-|_shared),\1~/.config/opencode/skills/\2,g'
}

# Fail when a description exceeds OpenCode's 1024-char cap. Truncation at a
# sentence boundary is the documented future policy; today nothing is close
# to the cap, so overflow means a source regression worth stopping on.
guard_desc() {
  len=$(printf '%s' "$1" | sed "s/^description: *//; s/^'//; s/'\$//" | wc -c | tr -d ' ')
  if [ "$len" -gt 1024 ]; then
    echo "description exceeds OpenCode's 1024-char cap in $2 ($len chars)" >&2
    exit 1
  fi
}

rm -rf "$OUT/commands" "$OUT/agents"
mkdir -p "$OUT/commands" "$OUT/agents"

for f in "$SRC"/commands/*.md; do
  name=$(basename "$f" .md)
  out="$OUT/commands/10x-$name.md"
  desc=$(fm_line "$f" description)
  [ -n "$desc" ] || { echo "missing description in $f" >&2; exit 1; }
  guard_desc "$desc" "$f"
  {
    echo "---"
    echo "$desc"
    echo "---"
    body_of "$f" | rewrite_paths | rewrite_tool_ids
  } > "$out"
done

for f in "$SRC"/agents/*.md; do
  name=$(basename "$f" .md)
  out="$OUT/agents/$name.md"
  desc=$(fm_line "$f" description)
  [ -n "$desc" ] || { echo "missing description in $f" >&2; exit 1; }
  guard_desc "$desc" "$f"
  # The tier is not written out (see the header) but the installer resolves
  # it from this source file, so an agent without one is still a defect.
  tier=$(fm_line "$f" model | sed 's/^model: *//')
  [ -n "$tier" ] || { echo "missing model tier in $f" >&2; exit 1; }
  tools=$(fm_line "$f" tools | sed 's/^tools: *//')
  skills=$(fm_line "$f" skills | sed 's/^skills: *//')

  # No tools: line in Claude Code means full inheritance; the port
  # preserves behavior, it never silently tightens.
  if [ -z "$tools" ]; then
    edit=allow bash=allow webfetch=allow
  else
    case "$tools" in *Edit*) edit=allow ;; *) edit=deny ;; esac
    case "$tools" in *Bash*) bash=allow ;; *) bash=deny ;; esac
    case "$tools" in *WebFetch*|*WebSearch*) webfetch=allow ;; *) webfetch=deny ;; esac
  fi

  {
    echo "---"
    echo "$desc"
    echo "mode: subagent"
    echo "permission:"
    echo "  edit: $edit"
    echo "  bash: $bash"
    echo "  webfetch: $webfetch"
    echo "---"
    if [ -n "$skills" ]; then
      echo "Read these skills first: $(printf '%s' "$skills" | sed 's/  */, /g')."
      echo ""
    fi
    body_of "$f" | rewrite_paths | rewrite_tool_ids
  } > "$out"
done

# Self-check: no Claude-only MCP tool id survived the rewrite. A surviving id
# has no row in tool-names.md, so it would reach OpenCode naming nothing.
stale_ids=$(grep -rn 'mcp__' "$OUT" || true)
if [ -n "$stale_ids" ]; then
  echo "unrewritten MCP tool id in generated output (add a row to $TOOL_TABLE):" >&2
  echo "$stale_ids" >&2
  exit 1
fi

# Self-check: no plugin-tree path reference survived the rewrite.
leftover=$(grep -rn '[ `(]skills/\(10x-\|lang-\|_shared\)\|`\.\./skills/\|`\.\./_shared/' "$OUT" || true)
if [ -n "$leftover" ]; then
  echo "unrewritten plugin-tree path reference in generated output:" >&2
  echo "$leftover" >&2
  exit 1
fi

echo "generated: $(ls "$OUT/commands" | wc -l | tr -d ' ') commands, $(ls "$OUT/agents" | wc -l | tr -d ' ') agents in $OUT/"
