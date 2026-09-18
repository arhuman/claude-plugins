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

The same content works in [OpenCode](https://opencode.ai). Skills are consumed
straight from source (they are OpenCode-valid as written); commands and agents
are converted into the committed `opencode/` tree by `scripts/gen-opencode.sh`
and kept in sync by CI. To install, clone this repo and run:

```bash
sh scripts/install-opencode.sh
```

This symlinks into `~/.config/opencode/`: the 11 commands (as `/10x-<name>`),
the 6 agents, and the 17 skills plus their shared `_shared` references.
`sh scripts/install-opencode.sh --uninstall` reverses it, removing only
symlinks that point into this repo.

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
