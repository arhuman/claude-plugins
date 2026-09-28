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
#   the installer guarantees: ~/.config/opencode/skills/;
# - the PostToolUse hooks are not converted: OpenCode has a JS plugin API,
#   so plugins/10x-hooks.js is emitted as an adapter that runs the very same
#   shell scripts from hooks.json. The checks keep one implementation.
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

rm -rf "$OUT/commands" "$OUT/agents" "$OUT/plugins"
mkdir -p "$OUT/commands" "$OUT/agents" "$OUT/plugins"

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

# The hook adapter. Static: it reads hooks.json at run time, so a hook added
# to the manifest reaches OpenCode without regenerating. It still lives here
# rather than as a hand-edited file under opencode/ so that the sync check's
# tree diff keeps owning everything in the generated tree.
# Node reads the adapter as ES module only with this beside it (OpenCode's
# Bun needs nothing); the installer links the .js alone, never this file.
printf '{ "type": "module" }\n' > "$OUT/plugins/package.json"
cat > "$OUT/plugins/10x-hooks.js" <<'JS'
// Generated by scripts/gen-opencode.sh: edit the heredoc there, not this file.
//
// OpenCode adapter for the plugin's PostToolUse hooks. No check lives here.
// After a write or edit it rebuilds the payload Claude Code would have sent,
// runs every command hooks.json declares for that tool, and appends what a
// hook reports to the tool output the model reads. The shell scripts stay
// the one implementation for both harnesses.
//
// Loaded from ~/.config/opencode/plugins/ (install-opencode.sh links it
// there). Run directly with an event on stdin to see what a hook would add:
//   printf '{"tool":"write","args":{"filePath":"/tmp/x.md","content":"a"},"output":""}' \
//     | node 10x-hooks.js
import { spawnSync } from "node:child_process";
import { readFileSync, realpathSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

// The installer links this file into the config tree, so the plugin root is
// found from the real location: opencode/plugins/ sits beside plugins/10x/.
const SELF = realpathSync(fileURLToPath(import.meta.url));
const PLUGIN_ROOT = resolve(dirname(SELF), "..", "..", "plugins", "10x");
const MANIFEST = join(PLUGIN_ROOT, "hooks", "hooks.json");

// OpenCode tool id to Claude Code tool name, and the argument names the
// hooks read (lib.sh: file_path, content, old_string, new_string).
const TOOLS = {
  write: { name: "Write", args: { filePath: "file_path", content: "content" } },
  edit: {
    name: "Edit",
    args: { filePath: "file_path", oldString: "old_string", newString: "new_string" },
  },
};

function payloadFor(tool, args) {
  const spec = TOOLS[tool];
  if (!spec || !args || typeof args !== "object") return null;
  const toolInput = {};
  for (const [from, to] of Object.entries(spec.args)) {
    if (args[from] !== undefined) toolInput[to] = args[from];
  }
  return { tool_name: spec.name, tool_input: toolInput };
}

// The PostToolUse commands of hooks.json whose matcher names this tool,
// verbatim: ${CLAUDE_PLUGIN_ROOT} is expanded by the shell, as under Claude
// Code, so the manifest stays the only place a hook is declared.
function commandsFor(toolName) {
  let manifest;
  try {
    manifest = JSON.parse(readFileSync(MANIFEST, "utf8"));
  } catch (err) {
    console.error(`10x hooks: cannot read ${MANIFEST}: ${err.message}`);
    return [];
  }
  const commands = [];
  for (const group of manifest.hooks?.PostToolUse ?? []) {
    if (group.matcher && !new RegExp(`^(?:${group.matcher})$`).test(toolName)) continue;
    for (const hook of group.hooks ?? []) {
      if (hook.type === "command" && hook.command) commands.push(hook.command);
    }
  }
  return commands;
}

// What a hook reports, under Claude Code's contract: exit 2 sends stderr
// back to the model; exit 0 with a JSON hookSpecificOutput adds its
// additionalContext. Anything else is for the user's log, not the model.
function reportOf(command, payload, cwd) {
  const run = spawnSync("sh", ["-c", command], {
    input: JSON.stringify(payload),
    cwd,
    encoding: "utf8",
    env: { ...process.env, CLAUDE_PLUGIN_ROOT: PLUGIN_ROOT, CLAUDE_PROJECT_DIR: cwd },
  });
  if (run.error) {
    console.error(`10x hooks: ${command}: ${run.error.message}`);
    return "";
  }
  if (run.status === 2) return run.stderr.trim();
  if (run.stderr.trim()) console.error(`10x hooks: ${command}: ${run.stderr.trim()}`);
  if (run.status !== 0) return "";
  try {
    const context = JSON.parse(run.stdout)?.hookSpecificOutput?.additionalContext;
    return typeof context === "string" ? context.trim() : "";
  } catch {
    return "";
  }
}

async function afterTool(input, output, cwd) {
  const payload = payloadFor(input.tool, input.args);
  if (!payload) return;
  for (const command of commandsFor(payload.tool_name)) {
    const text = reportOf(command, payload, cwd);
    if (text) output.output += `\n\n[10x hook ${basename(command)}] ${text}`;
  }
}

export const TenXHooks = async ({ directory }) => ({
  "tool.execute.after": (input, output) => afterTool(input, output, directory),
});

// Direct invocation (node or bun): one event on stdin, the tool output the
// model would read on stdout. This is what test-hooks.sh --harness opencode
// drives; OpenCode itself imports the module and never reaches this branch.
let direct = false;
try {
  direct = realpathSync(process.argv[1] ?? "") === SELF;
} catch {
  direct = false;
}
if (direct) {
  const event = JSON.parse(readFileSync(0, "utf8"));
  const output = { title: "", output: event.output ?? "", metadata: {} };
  await afterTool({ tool: event.tool, args: event.args }, output, process.cwd());
  process.stdout.write(output.output);
}
JS

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

echo "generated: $(ls "$OUT/commands" | wc -l | tr -d ' ') commands, $(ls "$OUT/agents" | wc -l | tr -d ' ') agents, $(ls "$OUT/plugins"/*.js | wc -l | tr -d ' ') plugin in $OUT/"
