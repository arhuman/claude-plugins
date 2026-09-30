#!/bin/sh
# Install (default) or remove (--uninstall) the OpenCode-facing tree as
# symlinks under ~/.config/opencode/: generated commands, agents and the
# hook adapter plugin from opencode/, and the skills straight from
# plugins/10x/skills/ (they are OpenCode-valid at source; _shared is linked
# as a sibling so the skills' ../_shared/references/... paths keep
# resolving). The plugin link must stay a link: the adapter finds the hook
# scripts from its real path in the repo.
#
# Idempotent. Never touches a target that exists and is not a symlink:
# real user files are warned about and skipped, both ways. Also never touches
# a symlink pointing into a different checkout: foreign symlinks are left alone.
# Uninstall only removes symlinks that resolve into this repo.
#
# --models binds each agent to a model id in opencode.json. The generated tree
# carries no model: an agent file's model: line overrides opencode.json
# (config.ts merges agent Markdown over the JSON), so a pinned id there could
# never be changed by the user. Binding in the JSON keeps the tree
# provider-neutral and the choice local. Commands are not bound: OpenCode's
# schema requires a full definition (template) on any command.<name> entry, so
# a JSON entry carrying only a model invalidates the whole config.
set -u

REPO=$(git rev-parse --show-toplevel 2>/dev/null)
[ -n "$REPO" ] || REPO=$(cd "$(dirname "$0")/.." && pwd)
CFG="$HOME/.config/opencode"
MODE=${1:-install}

linked=0 skipped=0 removed=0 orphans=0

link_one() {
  src=$1 dst=$2
  if [ ! -e "$src" ]; then
    echo "missing source: $src (run sh scripts/gen-opencode.sh first)" >&2
    exit 1
  fi
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "skip (exists, not a symlink): $dst"
    skipped=$((skipped + 1))
    return
  fi
  if [ -L "$dst" ]; then
    target=$(readlink "$dst")
    case "$target" in
      "$REPO"/*)
        # Symlink is already owned by this repo; safe to relink if source changed.
        ;;
      *)
        # Symlink points into a different checkout or elsewhere; leave it alone.
        echo "skip (foreign symlink, points into another checkout): $dst -> $target"
        skipped=$((skipped + 1))
        return
        ;;
    esac
  fi
  ln -sfn "$src" "$dst"
  echo "linked: $dst -> $src"
  linked=$((linked + 1))
}

plan_one() {
  src=$1 dst=$2
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "  skip (real file): $dst"
    skipped=$((skipped + 1))
    return
  fi
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "  unchanged:       $dst"
    return
  fi
  echo "  link:            $dst -> $src"
  linked=$((linked + 1))
}

unlink_one() {
  # Same (source, destination) signature as link_one; source is unused.
  dst=$2
  [ -L "$dst" ] || return 0
  case "$(readlink "$dst")" in
    "$REPO"/*)
      rm "$dst"
      echo "removed: $dst"
      removed=$((removed + 1))
      ;;
    *)
      echo "skip (symlink not owned by this repo): $dst"
      skipped=$((skipped + 1))
      ;;
  esac
}

# Sweep the managed directories for links this repo owns whose source is gone.
#
# each_target walks what the repo holds now, so a link left by a command or
# skill that has since been renamed or removed is never visited by install or
# uninstall: it is not in the loop. Sweeping the destination side is the only
# way to see it. Ownership is the same test uninstall uses, a target under
# $REPO, so a user's own link or file is never a candidate.
#
# $1 is the action: "list" prints, "prune" removes.
sweep_orphans() {
  act=$1
  for d in commands agents skills plugins; do
    for dst in "$CFG/$d"/*; do
      [ -L "$dst" ] || continue
      target=$(readlink "$dst")
      case "$target" in "$REPO"/*) ;; *) continue ;; esac
      [ -e "$dst" ] && continue
      if [ "$act" = prune ]; then
        rm "$dst"
        echo "pruned: $dst -> $target (source gone)"
        removed=$((removed + 1))
      else
        echo "orphan: $dst -> $target (source gone)"
        orphans=$((orphans + 1))
      fi
    done
  done
}

# Report every destination the current tree would manage, then the orphans.
# Reads only; the counterpart of --dry-run for an install already done.
list_one() {
  src=$1 dst=$2
  if [ ! -L "$dst" ]; then
    if [ -e "$dst" ]; then
      echo "unmanaged: $dst (real file, left alone)"
    else
      echo "absent:    $dst"
    fi
    return
  fi
  target=$(readlink "$dst")
  case "$target" in
    "$REPO"/*)
      if [ -e "$dst" ]; then
        echo "healthy:   $dst"
      else
        echo "broken:    $dst -> $target"
      fi
      ;;
    *) echo "foreign:   $dst -> $target" ;;
  esac
}

each_target() {
  # Calls $1 with (source, destination) for every artifact.
  act=$1
  for f in "$REPO"/opencode/commands/*.md; do
    "$act" "$f" "$CFG/commands/$(basename "$f")"
  done
  for f in "$REPO"/opencode/agents/*.md; do
    "$act" "$f" "$CFG/agents/$(basename "$f")"
  done
  for f in "$REPO"/opencode/plugins/*.js; do
    "$act" "$f" "$CFG/plugins/$(basename "$f")"
  done
  for d in "$REPO"/plugins/10x/skills/*/; do
    d=${d%/}
    name=$(basename "$d")
    if [ -f "$d/SKILL.md" ] || [ "$name" = "_shared" ]; then
      "$act" "$d" "$CFG/skills/$name"
    fi
  done
}

# Resolve the two PAL paths, in decreasing order of explicitness: the
# environment, then a --pal-path naming the PAL checkout, then the pal entry of
# ~/.claude.json if Claude Code already has one. The repo itself ships neither:
# both are absolute paths under someone's home.
resolve_pal() {
  arg_root=${1:-}
  pal_python=${PAL_PYTHON:-}
  pal_server=${PAL_SERVER:-}

  if [ -z "$pal_python" ] && [ -n "$arg_root" ]; then
    pal_python="$arg_root/.pal_venv/bin/python"
    pal_server="$arg_root/server.py"
  fi

  if [ -z "$pal_python" ] && [ -f "$HOME/.claude.json" ]; then
    # Claude Code stores the same server; reuse it rather than asking twice.
    eval "$(python3 - "$HOME/.claude.json" <<'PY'
import json, shlex, sys
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        doc = json.load(fh)
except Exception:
    sys.exit(0)

def walk(node):
    if isinstance(node, dict):
        servers = node.get("mcpServers")
        if isinstance(servers, dict):
            for name, cfg in servers.items():
                if name.lower() == "pal" and isinstance(cfg, dict):
                    return cfg
        for value in node.values():
            found = walk(value)
            if found:
                return found
    return None

cfg = walk(doc) or {}
cmd = cfg.get("command")
args = cfg.get("args") or []
if isinstance(cmd, str) and args:
    print("pal_python=%s" % shlex.quote(cmd))
    print("pal_server=%s" % shlex.quote(str(args[0])))
PY
)"
  fi

  if [ -z "$pal_python" ] || [ -z "$pal_server" ]; then
    cat >&2 <<'MSG'
cannot locate the PAL server. Give it one of:
  PAL_PYTHON=/path/to/venv/bin/python PAL_SERVER=/path/to/server.py sh scripts/install-opencode.sh --mcp
  sh scripts/install-opencode.sh --mcp --pal-path /path/to/pal-mcp-server
MSG
    return 1
  fi
}

# Merge the pal block into the user's opencode.json. Read-modify-write in
# python3: the file is the user's, carries their providers and models, and
# editing JSON with sed corrupts it silently.
# install_mcp [PAL_ROOT]
install_mcp() {
  resolve_pal "${1:-}" || exit 1
  for p in "$pal_python" "$pal_server"; do
    [ -e "$p" ] || echo "warning: $p does not exist yet" >&2
  done
  mkdir -p "$CFG"
  PAL_PYTHON_R=$pal_python PAL_SERVER_R=$pal_server \
  python3 - "$CFG/opencode.json" "$REPO/scripts/opencode-mcp-pal.template.json" <<'PY'
import json, os, sys

target, template = sys.argv[1], sys.argv[2]

with open(template, encoding="utf-8") as fh:
    block = json.load(fh)
resolved = json.loads(
    json.dumps(block)
    .replace("__PAL_PYTHON__", os.environ["PAL_PYTHON_R"])
    .replace("__PAL_SERVER__", os.environ["PAL_SERVER_R"])
)

try:
    with open(target, encoding="utf-8") as fh:
        doc = json.load(fh)
except FileNotFoundError:
    doc = {"$schema": "https://opencode.ai/config.json"}
except ValueError as exc:
    sys.exit("%s is not valid JSON (%s); fix or move it first" % (target, exc))

mcp = doc.setdefault("mcp", {})
if not isinstance(mcp, dict):
    sys.exit("%s has a non-object \"mcp\" key; fix it first" % target)

for name, cfg in resolved.items():
    existing = mcp.get(name)
    if existing == cfg:
        print("already declared, unchanged: mcp.%s" % name)
        continue
    if existing is not None:
        sys.exit(
            "mcp.%s already exists and differs; leaving it alone.\n"
            "  current: %s\n  would set: %s"
            % (name, json.dumps(existing), json.dumps(cfg))
        )
    mcp[name] = cfg
    print("declared: mcp.%s -> %s" % (name, " ".join(cfg["command"])))

# Write through a sibling temp file so an interrupted run cannot truncate the
# user's config.
tmp = target + ".10x-tmp"
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(doc, fh, indent=2)
    fh.write("\n")
os.replace(tmp, target)
PY
}

# Bind every agent to a model id in the user's opencode.json.
#
# Resolution: the override file (argument, else $CFG/10x-models.json when it
# exists) is merged key by key over scripts/opencode-models.json; an agent
# then takes its `agents` entry, else the entry of its tier under `tiers`.
# The tier is read from the plugin source frontmatter (model: opus|sonnet|
# haiku), the same word Claude Code consumes natively.
#
# The bound entries are owned by this installer and rewritten on every run:
# a value the user wants to keep belongs in the override file, not in
# opencode.json by hand. Every other key of the config is preserved.
#
# Also raises subagent_depth to 2 when it is lower, since agent-to-agent
# delegation is dead at OpenCode's default of 1. Grouped here because this is
# the mode that already owns opencode.json and needs no path resolution.
# install_models [OVERRIDE_FILE]
install_models() {
  override=${1:-}
  if [ -z "$override" ] && [ -f "$CFG/10x-models.json" ]; then
    override="$CFG/10x-models.json"
  fi
  if [ -n "$override" ] && [ ! -f "$override" ]; then
    echo "models override file not found: $override" >&2
    exit 2
  fi
  mkdir -p "$CFG"
  python3 - "$CFG/opencode.json" "$REPO" "$override" <<'PY'
import json, os, sys

target, repo, override = sys.argv[1], sys.argv[2], sys.argv[3]
KEYS = ("tiers", "agents")


def load_table(path, label):
    with open(path, encoding="utf-8") as fh:
        table = json.load(fh)
    if not isinstance(table, dict):
        sys.exit("%s: expected a JSON object" % label)
    unknown = sorted(set(table) - set(KEYS))
    if unknown:
        sys.exit("%s: unknown key(s) %s; allowed: %s"
                 % (label, ", ".join(unknown), ", ".join(KEYS)))
    for key in KEYS:
        block = table.setdefault(key, {})
        if not isinstance(block, dict):
            sys.exit("%s: %s must be an object" % (label, key))
        for name, model in block.items():
            if not isinstance(model, str) or not model.strip():
                sys.exit("%s: %s.%s must be a non-empty model id" % (label, key, name))
            if "/" not in model:
                sys.exit("%s: %s.%s = %r is not provider/model" % (label, key, name, model))
    return table


def tier_of(path):
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().split("\n")
    if not lines or lines[0] != "---":
        return None
    for line in lines[1:]:
        if line == "---":
            return None
        if line.startswith("model:"):
            return line[len("model:"):].strip() or None
    return None


def stems(subdir):
    d = os.path.join(repo, "plugins", "10x", subdir)
    return sorted(f[:-3] for f in os.listdir(d) if f.endswith(".md"))


table = load_table(os.path.join(repo, "scripts", "opencode-models.json"), "opencode-models.json")
if override:
    extra = load_table(override, override)
    for key in KEYS:
        table[key].update(extra[key])

agents = stems("agents")
unknown = sorted(set(table["agents"]) - set(agents))
if unknown:
    sys.exit("%s names agents the repo does not ship: %s"
             % (override or "opencode-models.json", ", ".join(unknown)))

wanted = {"agent": {}}
for name in agents:
    tier = tier_of(os.path.join(repo, "plugins", "10x", "agents", name + ".md"))
    if tier is None:
        sys.exit("agents/%s.md declares no model tier" % name)
    model = table["agents"].get(name) or table["tiers"].get(tier)
    if not model:
        sys.exit("no model for tier %r (agent %s); add tiers.%s to %s"
                 % (tier, name, tier, override or "the override file"))
    wanted["agent"][name] = model

try:
    with open(target, encoding="utf-8") as fh:
        doc = json.load(fh)
except FileNotFoundError:
    doc = {"$schema": "https://opencode.ai/config.json"}
except ValueError as exc:
    sys.exit("%s is not valid JSON (%s); fix or move it first" % (target, exc))

changed = 0

# Agents that delegate (coder, tester, conform) need two gates open under
# OpenCode: a task permission, which gen-opencode.sh writes per agent, and a
# subagent_depth above the default 1, which is global and belongs here. At 1 a
# primary may spawn a subagent but that subagent may not spawn another, so
# conform-agent's [Fix] dispatch and the coder/tester handoffs are inert.
# Raised when too low, never lowered: a higher value is the user's choice.
MIN_SUBAGENT_DEPTH = 2
depth = doc.get("subagent_depth")
if depth is None:
    doc["subagent_depth"] = MIN_SUBAGENT_DEPTH
    changed += 1
    print("set:       subagent_depth -> %d (agent delegation needs >= 2)"
          % MIN_SUBAGENT_DEPTH)
elif not isinstance(depth, int) or isinstance(depth, bool):
    sys.exit("%s: subagent_depth = %r is not an integer; fix it first"
             % (target, depth))
elif depth < MIN_SUBAGENT_DEPTH:
    doc["subagent_depth"] = MIN_SUBAGENT_DEPTH
    changed += 1
    print("raised:    subagent_depth %d -> %d (agent delegation needs >= 2)"
          % (depth, MIN_SUBAGENT_DEPTH))
else:
    print("unchanged: subagent_depth = %d" % depth)

for section, entries in wanted.items():
    block = doc.setdefault(section, {})
    if not isinstance(block, dict):
        sys.exit("%s has a non-object \"%s\" key; fix it first" % (target, section))
    for name, model in entries.items():
        entry = block.setdefault(name, {})
        if not isinstance(entry, dict):
            sys.exit("%s: %s.%s is not an object; fix it first" % (target, section, name))
        current = entry.get("model")
        if current == model:
            print("unchanged: %s.%s.model = %s" % (section, name, model))
            continue
        entry["model"] = model
        changed += 1
        if current is None:
            print("bound:     %s.%s.model -> %s" % (section, name, model))
        else:
            print("replaced:  %s.%s.model %s -> %s" % (section, name, current, model))

if changed:
    tmp = target + ".10x-tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(doc, fh, indent=2)
        fh.write("\n")
    os.replace(tmp, target)
print("done: %d binding(s) written to %s" % (changed, target))
PY
}

# Report the model bound to each shipped agent, changing nothing.
doctor_models() {
  python3 - "$CFG/opencode.json" "$REPO" <<'PY'
import json, os, sys
target, repo = sys.argv[1], sys.argv[2]
try:
    with open(target, encoding="utf-8") as fh:
        doc = json.load(fh)
except (FileNotFoundError, ValueError):
    doc = {}
unbound = 0
d = os.path.join(repo, "plugins", "10x", "agents")
for f in sorted(os.listdir(d)):
    if not f.endswith(".md"):
        continue
    name = f[:-3]
    model = ((doc.get("agent") or {}).get(name) or {}).get("model")
    if model:
        print("model: agent.%s -> %s" % (name, model))
    else:
        print("model: agent.%s unbound, inherits the primary agent's model (run --models)" % name)
        unbound += 1
sys.exit(1 if unbound else 0)
PY
}

# Report what is installed and whether PAL is reachable, changing nothing.
run_doctor() {
  rc=0

  # Use each_target list_one to walk the current repo's surface and report
  # every expected destination, including any that are absent (never linked).
  # This mirrors --list's categories (healthy/broken/foreign/absent) so missing
  # entries are visible, not hidden by an independent glob that only sees
  # what is already on disk.
  list_out=$(each_target list_one 2>&1)
  echo "$list_out"

  # Count and report managed links per directory.
  for d in commands agents skills plugins; do
    n=$(echo "$list_out" | grep "^healthy: *$CFG/$d/" | wc -l | tr -d ' ')
    echo "$d: $n managed link(s)"
  done

  # Fail if any absent or broken entries were found.
  if echo "$list_out" | grep -q "^absent:"; then
    rc=1
  fi
  if echo "$list_out" | grep -q "^broken:"; then
    rc=1
  fi

  if [ ! -f "$CFG/opencode.json" ]; then
    echo "mcp.pal: no $CFG/opencode.json (run --mcp)"
    doctor_models
    return 1
  fi
  python3 - "$CFG/opencode.json" <<'PY' || rc=1
import json, os, sys
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        doc = json.load(fh)
except ValueError as exc:
    sys.exit("mcp.pal: %s is not valid JSON (%s)" % (sys.argv[1], exc))
cfg = (doc.get("mcp") or {}).get("pal")
if not cfg:
    sys.exit("mcp.pal: not declared (run --mcp)")
cmd = cfg.get("command") or []
missing = [p for p in cmd if p.startswith("/") and not os.path.exists(p)]
if missing:
    sys.exit("mcp.pal: declared but missing on disk: %s" % ", ".join(missing))
if cfg.get("enabled") is False:
    print("mcp.pal: declared but disabled")
else:
    print("mcp.pal: declared and resolvable (%s)" % " ".join(cmd))
PY
  doctor_models || rc=1
  return $rc
}

# Check for and optionally remove mcp.pal and agent model bindings from opencode.json.
# purge_config [--purge] removes them; without --purge, just reports what was left.
purge_config() {
  purge=${1:-}
  if [ ! -f "$CFG/opencode.json" ]; then
    return 0
  fi
  python3 - "$CFG/opencode.json" "$REPO" "$purge" <<'PY'
import json, os, sys

target, repo, purge = sys.argv[1], sys.argv[2], sys.argv[3]

try:
    with open(target, encoding="utf-8") as fh:
        doc = json.load(fh)
except (FileNotFoundError, ValueError):
    sys.exit(0)

def stems(subdir):
    d = os.path.join(repo, "plugins", "10x", subdir)
    try:
        return sorted(f[:-3] for f in os.listdir(d) if f.endswith(".md"))
    except OSError:
        return []

has_pal = "mcp" in doc and "pal" in doc.get("mcp", {})
agents = stems("agents")
agent_entries = doc.get("agent", {})
model_bindings = [n for n in agents if n in agent_entries and "model" in agent_entries[n]]

if purge == "--purge":
    if has_pal or model_bindings:
        if has_pal:
            del doc["mcp"]["pal"]
            if not doc["mcp"]:
                del doc["mcp"]
        for name in model_bindings:
            del doc["agent"][name]["model"]
            if not doc["agent"][name]:
                del doc["agent"][name]
            if not doc["agent"]:
                del doc["agent"]

        tmp = target + ".10x-tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(doc, fh, indent=2)
            fh.write("\n")
        os.replace(tmp, target)
else:
    if has_pal or model_bindings:
        parts = []
        if has_pal:
            parts.append("mcp.pal")
        if model_bindings:
            count = len(model_bindings)
            binding_text = "model binding(s)" if count != 1 else "model binding"
            parts.append(f"{count} {binding_text}")

        what = " and ".join(parts)
        print(f"opencode.json still declares {what}; remove by hand or see --uninstall --purge-config")
PY
}

case "$MODE" in
  install)
    mkdir -p "$CFG/commands" "$CFG/agents" "$CFG/skills" "$CFG/plugins"
    each_target link_one
    echo "done: $linked linked, $skipped skipped"
    ;;
  --uninstall)
    each_target unlink_one
    # Orphans too: a link whose source was renamed away is still ours, and
    # leaving it behind is what made uninstall incomplete.
    sweep_orphans prune
    echo "done: $removed removed, $skipped skipped"
    if [ "${2:-}" = "--purge-config" ]; then
      purge_config --purge
    else
      purge_config
    fi
    ;;
  --list)
    each_target list_one
    sweep_orphans list
    echo "done: $orphans orphan(s)"
    ;;
  --prune)
    sweep_orphans prune
    echo "done: $removed pruned"
    ;;
  --dry-run)
    echo "would link into $CFG:"
    each_target plan_one
    sweep_orphans list
    echo "plan: $linked to link, $skipped to skip, $orphans orphan(s) to prune"
    ;;
  --mcp)
    case "${2:-}" in
      --pal-path)
        [ -n "${3:-}" ] || { echo "--pal-path needs a directory" >&2; exit 2; }
        install_mcp "$3"
        ;;
      "") install_mcp ;;
      *) echo "usage: sh scripts/install-opencode.sh --mcp [--pal-path DIR]" >&2; exit 2 ;;
    esac
    ;;
  --models)
    case "${2:-}" in
      "") install_models ;;
      -*) echo "usage: sh scripts/install-opencode.sh --models [FILE]" >&2; exit 2 ;;
      *) install_models "$2" ;;
    esac
    ;;
  --doctor)
    run_doctor
    ;;
  *)
    cat >&2 <<'MSG'
usage: sh scripts/install-opencode.sh [MODE]
  (none)       link commands, agents, skills and the hook plugin into ~/.config/opencode
  --dry-run    print what install would do, write nothing
  --list       report every managed path as healthy, broken, foreign or absent
  --prune      remove links this repo owns whose source no longer exists
  --uninstall [--purge-config]  remove this repo's links, orphans included;
               --purge-config also removes mcp.pal and agent model bindings
  --mcp [--pal-path DIR]  declare the PAL MCP server
  --models [FILE]  bind agents to model ids in opencode.json,
               from scripts/opencode-models.json plus FILE (default:
               ~/.config/opencode/10x-models.json when it exists)
  --doctor     report install, PAL and model bindings, write nothing
MSG
    exit 2
    ;;
esac
