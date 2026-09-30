#!/bin/sh
# Exercise install-opencode.sh against a temporary HOME. Every case asserts
# something a user would notice: a link made, a real file left alone, a config
# merged rather than overwritten, a refusal that says why.
#
# The real ~/.config/opencode is never touched: HOME is reassigned per case.
# Pass --mcp to run only the MCP cases.
set -u

REPO=$(git rev-parse --show-toplevel 2>/dev/null) || REPO=$(cd "$(dirname "$0")/.." && pwd)
INST="$REPO/scripts/install-opencode.sh"
ONLY=${1:-all}
ROOT=$(mktemp -d) || exit 1
trap 'rm -rf "$ROOT"' EXIT

pass=0 fail=0

ok() { pass=$((pass + 1)); }
ko() {
  echo "FAIL $1"
  shift
  [ $# -eq 0 ] || printf '  %s\n' "$@"
  fail=$((fail + 1))
}

# fresh_home <name>: an isolated HOME, printed on stdout.
fresh_home() {
  h="$ROOT/$1"
  mkdir -p "$h/.config/opencode"
  echo "$h"
}

# --- link lifecycle -------------------------------------------------------

if [ "$ONLY" != "--mcp" ]; then
  h=$(fresh_home links)
  HOME="$h" sh "$INST" >/dev/null 2>&1

  n=$(find "$h/.config/opencode/commands" -type l 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" -gt 0 ] && ok || ko "install/commands-linked" "no command symlink created"

  [ -L "$h/.config/opencode/skills/_shared" ] && ok \
    || ko "install/shared-linked" "_shared not linked, skill references would break"

  # The hook adapter is a link, not a copy: it locates the hook scripts from
  # its real path in the repo.
  [ -L "$h/.config/opencode/plugins/10x-hooks.js" ] \
    && [ "$(readlink "$h/.config/opencode/plugins/10x-hooks.js")" = "$REPO/opencode/plugins/10x-hooks.js" ] \
    && ok || ko "install/plugin-linked" "hook adapter not linked into plugins/"

  # Reinstall must be idempotent, not additive.
  before=$(find "$h/.config/opencode" -type l | sort)
  HOME="$h" sh "$INST" >/dev/null 2>&1
  after=$(find "$h/.config/opencode" -type l | sort)
  [ "$before" = "$after" ] && ok || ko "install/idempotent" "reinstall changed the link set"

  # A real file at a managed path is the user's; it must survive both ways.
  real="$h/.config/opencode/commands/10x-manual.md"
  rm -f "$real"
  printf 'my own file\n' > "$real"
  HOME="$h" sh "$INST" >/dev/null 2>&1
  [ ! -L "$real" ] && [ "$(cat "$real")" = "my own file" ] && ok \
    || ko "install/preserves-real-file" "a real file was replaced by a link"

  # A symlink pointing elsewhere is not ours to remove.
  printf 'elsewhere\n' > "$h/foreign-target.md"
  foreign="$h/.config/opencode/commands/foreign.md"
  ln -sfn "$h/foreign-target.md" "$foreign"
  HOME="$h" sh "$INST" --uninstall >/dev/null 2>&1
  [ -L "$foreign" ] && ok || ko "uninstall/leaves-foreign-symlink" "removed a link it does not own"
  [ -f "$real" ] && ok || ko "uninstall/preserves-real-file" "removed the user's real file"

  n=$(find "$h/.config/opencode/agents" "$h/.config/opencode/plugins" -type l 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" -eq 0 ] && ok || ko "uninstall/removes-own-links" "$n managed link(s) left behind"

  # A symlink pointing into another checkout must not be relinked during install.
  # This test plants a foreign symlink at a destination that matches a managed
  # skill name, so link_one will encounter it.
  h=$(fresh_home foreign-install)
  other_repo=$(mktemp -d) || exit 1
  trap 'rm -rf "$ROOT" "$other_repo"' EXIT
  mkdir -p "$other_repo/skills/loop"
  printf 'other skill\n' > "$other_repo/skills/loop/SKILL.md"
  mkdir -p "$h/.config/opencode/skills"
  foreign_skill="$h/.config/opencode/skills/loop"
  ln -sfn "$other_repo/skills/loop" "$foreign_skill"
  # Verify the symlink exists and points to the other repo before install.
  [ "$(readlink "$foreign_skill")" = "$other_repo/skills/loop" ] || exit 1
  out=$(HOME="$h" sh "$INST" 2>&1)
  # After install, it should still point to the other repo, not be relinked to the current repo.
  [ "$(readlink "$foreign_skill")" = "$other_repo/skills/loop" ] && ok \
    || ko "install/leaves-foreign-symlink-untouched" "relinked a foreign symlink: $(readlink "$foreign_skill")"
  printf '%s' "$out" | grep -q 'skip (foreign symlink.*loop' && ok \
    || ko "install/reports-foreign-symlink-skip" "did not report the foreign symlink as skipped in install output"
fi

# --- orphan links ---------------------------------------------------------
#
# A link whose source was renamed or removed upstream is invisible to both
# install and uninstall: each_target walks the current repo, and the link is not
# in it. Observed for real: 14 such links under the maintainer's config, left by
# skills renamed months earlier.

if [ "$ONLY" != "--mcp" ]; then
  h=$(fresh_home orphans)
  HOME="$h" sh "$INST" >/dev/null 2>&1

  # Forge what an earlier version of this repo would have left behind.
  orphan_cmd="$h/.config/opencode/commands/10x-gone.md"
  orphan_skill="$h/.config/opencode/skills/10x-old-name"
  orphan_plugin="$h/.config/opencode/plugins/10x-old-hooks.js"
  ln -sfn "$REPO/opencode/commands/10x-gone.md" "$orphan_cmd"
  ln -sfn "$REPO/plugins/10x/skills/10x-old-name" "$orphan_skill"
  ln -sfn "$REPO/opencode/plugins/10x-old-hooks.js" "$orphan_plugin"

  out=$(HOME="$h" sh "$INST" --list 2>&1)
  printf '%s' "$out" | grep -q 'orphan:.*10x-gone.md' && ok \
    || ko "list/reports-orphan" "an orphan link was not reported: $out"

  # A reinstall must not be considered a cleanup: it cannot see these.
  HOME="$h" sh "$INST" >/dev/null 2>&1
  [ -L "$orphan_cmd" ] && ok \
    || ko "install/does-not-hide-orphan" "install removed it, so --list would lie about the need"

  # A foreign link is never an orphan candidate, and the case that matters is a
  # foreign link that is ALSO dangling: only the ownership test spares it, so a
  # foreign link with a live target would pass even without that test.
  foreign="$h/.config/opencode/commands/not-ours.md"
  ln -sfn "$h/gone-elsewhere.md" "$foreign"
  out=$(HOME="$h" sh "$INST" --list 2>&1)
  printf '%s' "$out" | grep -q 'orphan:.*not-ours' \
    && ko "list/foreign-not-orphan" "claimed a dangling link it does not own" || ok

  out=$(HOME="$h" sh "$INST" --prune 2>&1)
  [ ! -L "$orphan_cmd" ] && [ ! -L "$orphan_skill" ] && [ ! -L "$orphan_plugin" ] && ok \
    || ko "prune/removes-orphans" "$out"
  [ -L "$foreign" ] && ok || ko "prune/keeps-foreign" "pruned a dangling link it does not own"

  n=$(find "$h/.config/opencode/commands" -type l 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" -gt 1 ] && ok || ko "prune/keeps-healthy" "pruned healthy links too ($n left)"

  # Uninstall must leave nothing of ours, orphans included.
  ln -sfn "$REPO/opencode/commands/10x-gone-again.md" \
    "$h/.config/opencode/commands/10x-gone-again.md"
  HOME="$h" sh "$INST" --uninstall >/dev/null 2>&1
  # grep rather than a nested case: /bin/sh on macOS mis-parses a case inside a
  # command substitution inside a loop, and the construct is not worth the risk.
  left=$(find "$h/.config/opencode" -type l -exec readlink {} + 2>/dev/null \
    | grep -c "^$REPO/" || true)
  [ "${left:-0}" -eq 0 ] && ok || ko "uninstall/removes-orphans" "$left link(s) into the repo left behind"

  # --dry-run writes nothing. Checked twice: on an empty home (nothing appears)
  # and after an install with one link deleted (the gap is not silently filled).
  h=$(fresh_home dryrun)
  out=$(HOME="$h" sh "$INST" --dry-run 2>&1)
  n=$(find "$h/.config/opencode" -type l 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" -eq 0 ] && printf '%s' "$out" | grep -q 'would link into' && ok \
    || ko "dry-run/writes-nothing" "created $n link(s)"

  HOME="$h" sh "$INST" >/dev/null 2>&1
  victim=$(find "$h/.config/opencode/commands" -type l | head -1)
  rm -f "$victim"
  before=$(find "$h/.config/opencode" -type l | sort)
  out=$(HOME="$h" sh "$INST" --dry-run 2>&1)
  after=$(find "$h/.config/opencode" -type l | sort)
  [ "$before" = "$after" ] && ok \
    || ko "dry-run/restores-nothing" "--dry-run recreated a deleted link"
  printf '%s' "$out" | grep -q "link: *$victim" && ok \
    || ko "dry-run/reports-missing-link" "did not plan the deleted link: $out"
fi

# --- mcp declaration ------------------------------------------------------

pal="$ROOT/pal"
mkdir -p "$pal/.pal_venv/bin"
printf '#!/bin/sh\n' > "$pal/.pal_venv/bin/python"
chmod +x "$pal/.pal_venv/bin/python"
printf 'x\n' > "$pal/server.py"

# No config at all: --mcp creates one carrying only what it declares.
h=$(fresh_home mcp-fresh)
rm -f "$h/.config/opencode/opencode.json"
out=$(HOME="$h" sh "$INST" --mcp --pal-path "$pal" 2>&1)
if python3 - "$h/.config/opencode/opencode.json" "$pal" <<'PY' >/dev/null 2>&1
import json, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
cfg = doc["mcp"]["pal"]
assert cfg["type"] == "local", cfg
assert cfg["command"] == [sys.argv[2] + "/.pal_venv/bin/python", sys.argv[2] + "/server.py"], cfg
PY
then ok; else ko "mcp/creates-config" "$out"; fi

# An existing config keeps its own keys: the merge must not overwrite the file.
h=$(fresh_home mcp-merge)
cat > "$h/.config/opencode/opencode.json" <<'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "model": "opencode/big-pickle",
  "provider": {"ollama": {"name": "Ollama"}}
}
JSON
out=$(HOME="$h" sh "$INST" --mcp --pal-path "$pal" 2>&1)
if python3 - "$h/.config/opencode/opencode.json" <<'PY' >/dev/null 2>&1
import json, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
assert doc["model"] == "opencode/big-pickle", doc
assert doc["provider"]["ollama"]["name"] == "Ollama", doc
assert "pal" in doc["mcp"], doc
PY
then ok; else ko "mcp/preserves-existing-keys" "$out"; fi

# Running it twice must not report a change the second time.
out=$(HOME="$h" sh "$INST" --mcp --pal-path "$pal" 2>&1)
printf '%s' "$out" | grep -q 'already declared' && ok \
  || ko "mcp/idempotent" "second run did not report an unchanged entry: $out"

# A differing pal entry is the user's decision; refuse rather than clobber it.
h=$(fresh_home mcp-conflict)
cat > "$h/.config/opencode/opencode.json" <<'JSON'
{"mcp": {"pal": {"type": "local", "command": ["/usr/bin/python3", "/opt/other/server.py"]}}}
JSON
out=$(HOME="$h" sh "$INST" --mcp --pal-path "$pal" 2>&1)
rc=$?
if [ "$rc" != 0 ] && printf '%s' "$out" | grep -q 'already exists and differs'; then
  before=$(cat "$h/.config/opencode/opencode.json")
  printf '%s' "$before" | grep -q '/opt/other/server.py' && ok \
    || ko "mcp/conflict-preserves" "the differing entry was modified"
else
  ko "mcp/conflict-refused" "expected a nonzero refusal, got rc=$rc: $out"
fi

# Unresolvable paths: no env, no --pal-path, no ~/.claude.json to fall back on.
h=$(fresh_home mcp-unresolvable)
out=$(env -u PAL_PYTHON -u PAL_SERVER HOME="$h" sh "$INST" --mcp 2>&1)
rc=$?
if [ "$rc" != 0 ] && printf '%s' "$out" | grep -q 'cannot locate the PAL server'; then ok
else ko "mcp/unresolvable-refused" "expected a nonzero refusal, got rc=$rc: $out"; fi

# --pal-path with no directory is a usage error, not a silent default.
out=$(HOME="$h" sh "$INST" --mcp --pal-path 2>&1)
[ "$?" = 2 ] && ok || ko "mcp/pal-path-needs-arg" "expected exit 2, got: $out"

# The environment wins over --pal-path.
h=$(fresh_home mcp-env)
rm -f "$h/.config/opencode/opencode.json"
PAL_PYTHON=/env/python PAL_SERVER=/env/server.py HOME="$h" \
  sh "$INST" --mcp --pal-path "$pal" >/dev/null 2>&1
if python3 - "$h/.config/opencode/opencode.json" <<'PY' >/dev/null 2>&1
import json, sys
cfg = json.load(open(sys.argv[1], encoding="utf-8"))["mcp"]["pal"]
assert cfg["command"] == ["/env/python", "/env/server.py"], cfg
PY
then ok; else ko "mcp/env-precedence" "PAL_PYTHON did not win over --pal-path"; fi

# --- model binding --------------------------------------------------------
#
# The generated agents carry no model: OpenCode merges agent Markdown over
# opencode.json, so a model there could never be overridden. --models writes
# the binding into opencode.json from the repo table plus a local override.
# Commands are never written: OpenCode refuses a command.<name> entry without
# a template, so binding one there invalidated the whole config (seen live).

OPUS_DEFAULT=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["tiers"]["opus"])' \
  "$REPO/scripts/opencode-models.json")

# No config at all: --models creates one carrying the default bindings.
h=$(fresh_home models-fresh)
rm -f "$h/.config/opencode/opencode.json"
out=$(HOME="$h" sh "$INST" --models 2>&1)
if OPUS_DEFAULT="$OPUS_DEFAULT" python3 - "$h/.config/opencode/opencode.json" <<'PY' >/dev/null 2>&1
import json, os, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
assert doc["agent"]["coder-agent"]["model"] == os.environ["OPUS_DEFAULT"], doc
assert doc["agent"]["fixer-agent"]["model"] != doc["agent"]["coder-agent"]["model"], doc
assert "command" not in doc, doc
PY
then ok; else ko "models/creates-config" "$out"; fi

# Running it twice must not report a change the second time.
out=$(HOME="$h" sh "$INST" --models 2>&1)
printf '%s' "$out" | grep -q 'done: 0 binding' && ok \
  || ko "models/idempotent" "second run wrote again: $out"

# An existing config keeps its own keys, including other fields of the same
# agent entry: the binding sets one field, never replaces the object.
h=$(fresh_home models-merge)
cat > "$h/.config/opencode/opencode.json" <<'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "model": "opencode/big-pickle",
  "provider": {"ollama": {"name": "Ollama"}},
  "agent": {"coder-agent": {"prompt": "keep me"}, "mine": {"model": "ollama/mine"}}
}
JSON
out=$(HOME="$h" sh "$INST" --models 2>&1)
if python3 - "$h/.config/opencode/opencode.json" <<'PY' >/dev/null 2>&1
import json, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
assert doc["model"] == "opencode/big-pickle", doc
assert doc["provider"]["ollama"]["name"] == "Ollama", doc
assert doc["agent"]["coder-agent"]["prompt"] == "keep me", doc
assert "model" in doc["agent"]["coder-agent"], doc
assert doc["agent"]["mine"] == {"model": "ollama/mine"}, doc
PY
then ok; else ko "models/preserves-existing-keys" "$out"; fi

# subagent_depth gates agent-to-agent delegation: OpenCode's default of 1 lets
# a primary spawn a subagent but stops that subagent spawning another, which
# kills conform-agent's [Fix] dispatch. Absent or too low is raised to 2; a
# higher value the user chose is left alone.
h=$(fresh_home models-depth)
out=$(HOME="$h" sh "$INST" --models 2>&1)
if python3 - "$h/.config/opencode/opencode.json" <<'PY' >/dev/null 2>&1
import json, sys
assert json.load(open(sys.argv[1], encoding="utf-8"))["subagent_depth"] == 2
PY
then ok; else ko "models/depth-set-when-absent" "$out"; fi

h=$(fresh_home models-depth-low)
printf '{"subagent_depth": 1}\n' > "$h/.config/opencode/opencode.json"
out=$(HOME="$h" sh "$INST" --models 2>&1)
if python3 - "$h/.config/opencode/opencode.json" <<'PY' >/dev/null 2>&1
import json, sys
assert json.load(open(sys.argv[1], encoding="utf-8"))["subagent_depth"] == 2
PY
then ok; else ko "models/depth-raised-from-default" "$out"; fi

h=$(fresh_home models-depth-high)
printf '{"subagent_depth": 5}\n' > "$h/.config/opencode/opencode.json"
out=$(HOME="$h" sh "$INST" --models 2>&1)
if python3 - "$h/.config/opencode/opencode.json" <<'PY' >/dev/null 2>&1
import json, sys
assert json.load(open(sys.argv[1], encoding="utf-8"))["subagent_depth"] == 5
PY
then ok; else ko "models/depth-preserves-higher" "$out"; fi

# A non-integer is the user's typo, not ours to coerce.
h=$(fresh_home models-depth-bad)
printf '{"subagent_depth": "2"}\n' > "$h/.config/opencode/opencode.json"
out=$(HOME="$h" sh "$INST" --models 2>&1)
rc=$?
[ "$rc" != 0 ] && printf '%s' "$out" | grep -q 'is not an integer' && ok \
  || ko "models/depth-rejects-non-integer" "$out"

# A tier override rebinds every agent of that tier and no other.
h=$(fresh_home models-tier)
printf '{"tiers": {"opus": "openai/gpt-5.5"}}\n' > "$h/tiers.json"
out=$(HOME="$h" sh "$INST" --models "$h/tiers.json" 2>&1)
if OPUS_DEFAULT="$OPUS_DEFAULT" python3 - "$h/.config/opencode/opencode.json" <<'PY' >/dev/null 2>&1
import json, os, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
assert doc["agent"]["coder-agent"]["model"] == "openai/gpt-5.5", doc
assert doc["agent"]["tester-agent"]["model"] != "openai/gpt-5.5", doc
PY
then ok; else ko "models/tier-override" "$out"; fi

# A per-agent entry wins over the agent's tier.
printf '{"tiers": {"opus": "openai/gpt-5.5"}, "agents": {"coder-agent": "ollama/local"}}\n' > "$h/agents.json"
out=$(HOME="$h" sh "$INST" --models "$h/agents.json" 2>&1)
grep -q '"model": "ollama/local"' "$h/.config/opencode/opencode.json" && ok \
  || ko "models/agent-override" "$out"

# Without an argument, ~/.config/opencode/10x-models.json is the override.
h=$(fresh_home models-implicit)
printf '{"tiers": {"haiku": "ollama/small"}}\n' > "$h/.config/opencode/10x-models.json"
out=$(HOME="$h" sh "$INST" --models 2>&1)
grep -q '"model": "ollama/small"' "$h/.config/opencode/opencode.json" && ok \
  || ko "models/implicit-override-file" "$out"

# Refusals write nothing: an unknown top-level key, a name the repo does not
# ship (a typo would otherwise bind nothing and say so nowhere), an id that
# is not provider/model, and a missing override file.
h=$(fresh_home models-refuse)
rm -f "$h/.config/opencode/opencode.json"
for case in 'unknown-key {"tier": {}}' \
            'commands-key {"commands": {"10x-manual": "x/y"}}' \
            'unknown-agent {"agents": {"coder": "x/y"}}' \
            'bad-id {"tiers": {"opus": "gpt-5.5"}}'; do
  name=${case%% *}
  printf '%s\n' "${case#* }" > "$h/$name.json"
  out=$(HOME="$h" sh "$INST" --models "$h/$name.json" 2>&1)
  rc=$?
  [ "$rc" != 0 ] && [ ! -f "$h/.config/opencode/opencode.json" ] && ok \
    || ko "models/refuses-$name" "rc=$rc: $out"
done
out=$(HOME="$h" sh "$INST" --models "$h/absent.json" 2>&1)
[ "$?" = 2 ] && ok || ko "models/missing-file-is-usage-error" "$out"

# --- doctor ---------------------------------------------------------------

h=$(fresh_home doctor-missing)
rm -f "$h/.config/opencode/opencode.json"
out=$(HOME="$h" sh "$INST" --doctor 2>&1)
[ "$?" != 0 ] && printf '%s' "$out" | grep -q 'run --mcp' && ok \
  || ko "doctor/reports-missing-config" "$out"

h=$(fresh_home doctor-ok)
rm -f "$h/.config/opencode/opencode.json"
HOME="$h" sh "$INST" >/dev/null 2>&1
HOME="$h" sh "$INST" --mcp --pal-path "$pal" >/dev/null 2>&1
HOME="$h" sh "$INST" --models >/dev/null 2>&1
out=$(HOME="$h" sh "$INST" --doctor 2>&1)
rc=$?
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'declared and resolvable' && ok \
  || ko "doctor/reports-healthy" "rc=$rc: $out"
printf '%s' "$out" | grep -q 'model: agent.coder-agent -> ' && ok \
  || ko "doctor/reports-bindings" "$out"

# An agent left unbound inherits the primary model silently; doctor must say so.
h=$(fresh_home doctor-unbound)
rm -f "$h/.config/opencode/opencode.json"
HOME="$h" sh "$INST" >/dev/null 2>&1
HOME="$h" sh "$INST" --mcp --pal-path "$pal" >/dev/null 2>&1
out=$(HOME="$h" sh "$INST" --doctor 2>&1)
[ "$?" != 0 ] && printf '%s' "$out" | grep -q 'coder-agent unbound' && ok \
  || ko "doctor/reports-unbound" "$out"

# A declared command that is not on disk must be reported, not called healthy.
h=$(fresh_home doctor-broken)
rm -f "$h/.config/opencode/opencode.json"
PAL_PYTHON=/nope/python PAL_SERVER=/nope/server.py HOME="$h" \
  sh "$INST" --mcp >/dev/null 2>&1
out=$(HOME="$h" sh "$INST" --doctor 2>&1)
[ "$?" != 0 ] && printf '%s' "$out" | grep -q 'missing on disk' && ok \
  || ko "doctor/reports-missing-binary" "$out"

# --- uninstall config handling -----------------------------------------------
#
# P29: uninstall leaves mcp.pal and model bindings by default, and provides
# --purge-config to remove them explicitly. Unrelated config keys must survive.

h=$(fresh_home uninstall-config)
rm -f "$h/.config/opencode/opencode.json"

# Install links, then --mcp and --models to populate config entries.
HOME="$h" sh "$INST" >/dev/null 2>&1
HOME="$h" sh "$INST" --mcp --pal-path "$pal" >/dev/null 2>&1
HOME="$h" sh "$INST" --models >/dev/null 2>&1

# Plant a marker key that uninstall must not touch.
python3 - "$h/.config/opencode/opencode.json" <<'PY'
import json, sys
cfg = sys.argv[1]
with open(cfg, "r") as f:
    doc = json.load(f)
doc["my_custom_key"] = "preserve me"
with open(cfg, "w") as f:
    json.dump(doc, f, indent=2)
    f.write("\n")
PY

# Verify both mcp.pal and model bindings exist before plain uninstall.
if python3 - "$h/.config/opencode/opencode.json" <<'PY' >/dev/null 2>&1
import json, sys
doc = json.load(open(sys.argv[1], "r"))
assert "pal" in doc.get("mcp", {}), "mcp.pal missing"
assert any("model" in doc.get("agent", {}).get(n, {})
           for n in ["coder-agent", "fixer-agent", "tester-agent"]), "no agent models"
PY
then ok; else ko "uninstall-config/setup" "config not populated correctly"; fi

# Plain --uninstall must leave both mcp.pal and model bindings.
out=$(HOME="$h" sh "$INST" --uninstall 2>&1)
if python3 - "$h/.config/opencode/opencode.json" <<'PY' >/dev/null 2>&1
import json, sys
doc = json.load(open(sys.argv[1], "r"))
assert "pal" in doc.get("mcp", {}), "mcp.pal was removed"
assert any("model" in doc.get("agent", {}).get(n, {})
           for n in ["coder-agent", "fixer-agent", "tester-agent"]), "model bindings were removed"
PY
then ok; else ko "uninstall-config/leaves-mcp-pal" "mcp.pal or models were removed"; fi

if python3 - "$h/.config/opencode/opencode.json" <<'PY' >/dev/null 2>&1
import json, sys
doc = json.load(open(sys.argv[1], "r"))
assert doc.get("my_custom_key") == "preserve me", "marker key was modified"
PY
then ok; else ko "uninstall-config/preserves-marker" "marker key was not preserved"; fi

printf '%s' "$out" | grep -q 'opencode.json still declares.*mcp.pal.*model binding' && ok \
  || ko "uninstall-config/warns-about-leftovers" "warning not printed: $out"

# --uninstall --purge-config must remove both.
out=$(HOME="$h" sh "$INST" --uninstall --purge-config 2>&1)
if python3 - "$h/.config/opencode/opencode.json" <<'PY' >/dev/null 2>&1
import json, sys
doc = json.load(open(sys.argv[1], "r"))
assert "pal" not in doc.get("mcp", {}), "mcp.pal was not removed"
assert not any("model" in doc.get("agent", {}).get(n, {})
               for n in ["coder-agent", "fixer-agent", "tester-agent"]), "model bindings were not removed"
PY
then ok; else ko "uninstall-config/purge-removes-config" "mcp.pal or models were not removed"; fi

if python3 - "$h/.config/opencode/opencode.json" <<'PY' >/dev/null 2>&1
import json, sys
doc = json.load(open(sys.argv[1], "r"))
assert doc.get("my_custom_key") == "preserve me", "marker key was modified"
PY
then ok; else ko "uninstall-config/purge-preserves-marker" "marker key was not preserved after purge"; fi

# --- doctor detecting absent entries ----------------------------------------
#
# P30: --doctor must report entries that exist in the repo's shipped surface
# but have never been linked (no link in the config tree). This closes the gap
# where a new command/agent/skill could be added without reinstalling and
# doctor would silently pass, only --list showing the problem.

h=$(fresh_home doctor-absent)
rm -f "$h/.config/opencode/opencode.json"
# Install everything that exists in the repo now.
HOME="$h" sh "$INST" >/dev/null 2>&1
HOME="$h" sh "$INST" --mcp --pal-path "$pal" >/dev/null 2>&1
HOME="$h" sh "$INST" --models >/dev/null 2>&1

# Doctor should pass: all shipped artifacts are linked and models are bound.
out=$(HOME="$h" sh "$INST" --doctor 2>&1)
rc=$?
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'declared and resolvable' && ok \
  || ko "doctor/healthy-after-install" "expected exit 0 with healthy doctor; rc=$rc; out=$out"

# P30 test: when a new command/agent/skill is added to the repo without
# reinstalling, doctor should report it as absent.
# We cannot directly add to REPO, so we monkey-patch each_target to include
# an extra artifact, then verify doctor reports it as absent.
h=$(fresh_home doctor-absent-check)
rm -f "$h/.config/opencode/opencode.json"

# Install everything that exists in the repo now.
HOME="$h" sh "$INST" >/dev/null 2>&1
HOME="$h" sh "$INST" --mcp --pal-path "$pal" >/dev/null 2>&1
HOME="$h" sh "$INST" --models >/dev/null 2>&1

# Create a temporary wrapper script that simulates a new command existing in the repo.
# We'll add a temporary file to the repo's opencode tree, then run doctor.
# To avoid polluting the real REPO, we use a simple approach:
# Create a fake artifact by modifying each_target on the fly via a wrapper.
# Instead, let's just manually add an absent entry to test it.

# Simpler approach: manually craft a list output with an absent: entry and test that
# doctor correctly reports it as a failure. But we need the real doctor to encounter it.
# The safest approach: add a temporary command file to REPO, run doctor, then remove it.
temp_cmd="$REPO/opencode/commands/10x-test-absent-cmd.md"
cat > "$temp_cmd" <<'CMD'
---
title: Temp Test Command
model: haiku
tools:
---
Temporary test command.
CMD

# Now run doctor; it should report the new command as absent since we didn't reinstall.
out=$(HOME="$h" sh "$INST" --doctor 2>&1)
rc=$?

# Clean up the temp file immediately.
rm -f "$temp_cmd"

if [ "$rc" != 0 ] && printf '%s' "$out" | grep -q 'absent:.*10x-test-absent-cmd.md'; then
  ok
else
  ko "doctor/reports-absent-command" "expected non-zero rc and absent line; rc=$rc; out=$out"
fi

echo "install-opencode: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
