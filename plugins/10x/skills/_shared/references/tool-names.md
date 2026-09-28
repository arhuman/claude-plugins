# MCP tool ids per harness (single source of truth)

An MCP tool is named by the host, not by the server, so the same tool is called
by a different id in each harness. Plugin sources are written with the Claude
Code ids; `scripts/gen-opencode.sh` rewrites them from the table below when it
generates `opencode/`.

Claude Code: `mcp__<server>__<tool>`, two underscores on each side of the server
name. OpenCode: `<server>_<tool>`, one underscore, the server name as declared
in `opencode.json` ([MCP servers](https://opencode.ai/docs/mcp-servers/),
[Agents](https://opencode.ai/docs/agents/), where the same id form is what
permission globs like `pal_*` match).

## PAL

| Claude Code | OpenCode | Used by |
|---|---|---|
| `mcp__pal__chat` | `pal_chat` | /tellme, /evaluate |
| `mcp__pal__consensus` | `pal_consensus` | coder-agent, /tellme |
| `mcp__pal__thinkdeep` | `pal_thinkdeep` | coder-agent, /tellme |
| `mcp__pal__debug` | `pal_debug` | coder-agent, tester-agent |
| `mcp__pal__listmodels` | `pal_listmodels` | /tellme, /evaluate |

Only ids appearing in a generated surface (`plugins/10x/commands/`,
`plugins/10x/agents/`) need a row: the generator fails on any `mcp__` it cannot
rewrite, so an id used in a new command or agent must be added here first.

`plugins/10x/README.md` keeps the Claude Code form and is not rewritten: it
documents Claude Code's permission prefix (`mcp__pal__*`), which is a fact about
that harness rather than a tool call.

## Adding a server

Add one section per server, with every tool the plugin names. The rewrite is a
literal substitution, so a row must give the exact id as written in the source,
backticks excluded.
