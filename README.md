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
/plugin install introspect
```

## Plugins

| Plugin | Purpose |
|--------|---------|
| `10x` | Skills, agents, and commands for efficient coding: six-axis code review, language standards (Go, TypeScript, HTML, SQL), Docker, Makefiles, testing, documentation, standard conformance |
| `introspect` | Local analytics on your own Claude Code usage: prompt volume, skill and agent triggers, corrections |

`global-project-manager` was removed in favour of [mnemos](https://github.com/arhuman/mnemos),
which stores tasks in an indexed knowledge tree. Its S3 sync tool, `s4ync`, was extracted
into its own repository.
