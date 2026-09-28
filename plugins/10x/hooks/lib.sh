# Shared input side of the PostToolUse hooks. Sourced, never executed.
#
# Parsing is python3, not jq: python3 is already required by the repo's checks
# (scripts/check-skill-tokens.py), so depending on it removes a dependency
# instead of guarding one. jq was the only tool a hook needed that CI never
# installs, which is how all three came to be silently inert without it.
#
# A hook must never block an edit because a tool is missing, so a missing
# python3 still exits 0. It says so on stderr first: the failure mode this
# replaces was silence, not strictness.
#
# The payload shape read here (tool_input.file_path, content, old_string,
# new_string, edits[]) is the contract for both harnesses: under OpenCode the
# generated opencode/plugins/10x-hooks.js rebuilds it from the tool.execute.after
# event and runs these same scripts. A new key read here must be mapped there.

# hook_payload: read the hook JSON from stdin into $HOOK_JSON.
# Call once, before any other helper. Exits 0 (skipping the check) when
# python3 is unavailable.
hook_payload() {
  if ! command -v python3 >/dev/null 2>&1; then
    echo "10x hooks: python3 missing, checks skipped" >&2
    exit 0
  fi
  HOOK_JSON=$(cat)
}

# hook_field <key>: print .tool_input.<key>, empty when absent.
hook_field() {
  printf '%s' "$HOOK_JSON" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
v=(d.get("tool_input") or {}).get(sys.argv[1])
if v is not None: sys.stdout.write(str(v))
' "$1" 2>/dev/null
}

# hook_strings <new|old>: print the written (new) or pre-existing (old) text of
# a Write or Edit, joined by newlines. Covers content, new_string/old_string,
# and every entry of an edits array, matching what the tools actually send.
hook_strings() {
  printf '%s' "$HOOK_JSON" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
ti=d.get("tool_input") or {}
which=sys.argv[1]
keys=("content","new_string") if which=="new" else ("old_string",)
out=[]
for k in keys:
    v=ti.get(k)
    if v is not None: out.append(str(v))
ek=("new_string" if which=="new" else "old_string")
for e in (ti.get("edits") or []):
    if isinstance(e,dict):
        v=e.get(ek)
        if v is not None: out.append(str(v))
sys.stdout.write("\n".join(out))
' "$1" 2>/dev/null
}
