# Arhuman Claude Code Plugins Directory

Just a bunch of plugins for Claude Code.

## Install Marketplace

In claude code

```bash
/plugin marketplace add arhuman/claude-plugins
```

## Install a plugin

```bash
/plugin install 10x
```

## Install for OpenCode

Most of the plugin works in [OpenCode](https://opencode.ai); what does and
what does not is the "Harness support" matrix in `plugins/10x/README.md`,
checked in CI against the tree. Skills are consumed straight from source (they
are OpenCode-valid as written); commands and agents are converted into the
committed `opencode/` tree by `scripts/gen-opencode.sh` and kept in sync by
CI. The three PostToolUse hooks are ported too, through a generated OpenCode
plugin (`opencode/plugins/10x-hooks.js`) that runs the very same shell scripts
on OpenCode's `tool.execute.after` event. To install, clone this repo and run:

```bash
sh scripts/install-opencode.sh
```

This symlinks into `~/.config/opencode/`: the 11 commands (as `/10x-<name>`),
the 6 agents, the hook plugin, and the 16 skills plus their shared `_shared`
references. `sh scripts/install-opencode.sh --uninstall` reverses it, removing
only symlinks that point into this repo. `make install-opencode` runs the
install and the model binding below in one step.

### Models under OpenCode

Each agent declares a model *tier* in its source frontmatter (`model: opus`,
`sonnet` or `haiku`), the vocabulary Claude Code consumes natively. The
generated OpenCode files carry no model at all: OpenCode merges an agent's
Markdown over `opencode.json`, so an id written there could never be
overridden by you. The binding is written into `opencode.json` instead:

```bash
sh scripts/install-opencode.sh --models              # repo defaults, plus ~/.config/opencode/10x-models.json if present
sh scripts/install-opencode.sh --models my-models.json
```

`scripts/opencode-models.json` maps each tier to a public model id. Your
override file uses the same shape and wins key by key; a per-agent entry wins
over the agent's tier:

```json
{
  "tiers": {"opus": "opencode/gpt-5.6-sol", "haiku": "ollama/qwen3:4b"},
  "agents": {"tester-agent": "anthropic/claude-sonnet-4-5"}
}
```

Ids are `provider/model` as your `opencode.json` declares them. The command
sets `agent.<name>.model`, preserves every other key of the config, and
rewrites those entries on every run: a choice you want to keep belongs in the
override file, not in `opencode.json` by hand. It refuses a file naming an
agent the repo does not ship, an unknown key, or an id without a provider.
Agents left unbound inherit the primary agent's model; `--doctor` reports each
binding and flags the unbound ones.

Commands are not bound. The two that declare a tier (`audit_ui`, `manual`) run
with the session's model under OpenCode: its config schema requires a full
definition (`template`) on any `command.<name>` entry, so a model alone there
invalidates the whole config.

### PAL under OpenCode

The agents and commands that consult PAL need the server declared in OpenCode,
which is separate from installing the files. Two steps, because a tool id and a
server declaration are different things: `gen-opencode.sh` rewrites the tool ids
to OpenCode's `pal_<tool>` form (see
`plugins/10x/skills/_shared/references/tool-names.md`), and the command below
declares the server.

```bash
sh scripts/install-opencode.sh --mcp     # declare mcp.pal in ~/.config/opencode/opencode.json
sh scripts/install-opencode.sh --doctor  # report managed links, PAL, and model bindings
```

`--mcp` merges one `mcp.pal` block into your existing config, preserving every
other key, and refuses rather than overwrite a `pal` entry that already differs.
It finds the server from `$PAL_PYTHON`/`$PAL_SERVER`, else `--pal-path DIR`
naming a PAL checkout, else the `pal` entry of `~/.claude.json`. The repo ships
only a placeholder template: an absolute path under one person's home is not
something a plugin can carry.

### Inspecting and repairing an install

```bash
sh scripts/install-opencode.sh --list      # every managed path: healthy, broken, foreign, absent
sh scripts/install-opencode.sh --dry-run   # what an install would do, writes nothing
sh scripts/install-opencode.sh --prune     # remove this repo's links whose source is gone
```

Orphan links accumulate whenever a command or skill is renamed upstream:
`install` and `uninstall` both walk what the repo holds *now*, so a link left by
a name that no longer exists is never visited by either. `--prune` sweeps the
destination side instead, and `--uninstall` now does the same before finishing.

Both only ever touch symlinks pointing into this repo. A real file, or a link
into another checkout, is reported and left alone: `--list` labels those
`unmanaged` and `foreign`. A stale real directory at a managed path (a `_shared`
copied rather than linked, say) is therefore `unmanaged` and needs removing by
hand before the installer can link it.

`opencode plugin add 'github:arhuman/claude-plugins#main::path:...'` is not
supported yet: the upstream installer reads `package.json` at the repo root
regardless of the `::path:` selector, and this repo deliberately carries no
root `package.json`. The installer above is the supported path until that is
resolved.

## Plugins

| Plugin | Purpose |
|--------|---------|
| `10x` | Skills, agents, and commands for efficient coding: language standards (Go, TypeScript, HTML, SQL), Docker, Makefiles, testing, documentation, standard conformance, plan-driven work loop |

`global-project-manager` was removed in favour of [mnemos](https://github.com/arhuman/mnemos),
which stores tasks in an indexed knowledge tree. Its S3 sync tool, `s4ync`, was extracted
into its own repository.
