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
| `mcp__pal__chat` | `pal_chat` | `pal-routing.md` callers, /evaluate |
| `mcp__pal__consensus` | `pal_consensus` | `pal-routing.md` callers |
| `mcp__pal__thinkdeep` | `pal_thinkdeep` | `pal-routing.md` callers |
| `mcp__pal__debug` | `pal_debug` | `pal-routing.md` callers |
| `mcp__pal__listmodels` | `pal_listmodels` | `pal-routing.md` callers, /evaluate |

## tree-sitter

Declared by the user, not by `install-opencode.sh --mcp` (which declares `pal`
only), so the server name below is the conventional one: a different name in
`opencode.json` changes the OpenCode id and needs this table updated to match.

| Claude Code | OpenCode | Used by |
|---|---|---|
| `mcp__tree_sitter__get_symbols` | `tree_sitter_get_symbols` | simplify-agent, documentation-agent, tester-agent |
| `mcp__tree_sitter__find_usage` | `tree_sitter_find_usage` | simplify-agent, coder-agent |
| `mcp__tree_sitter__find_similar_code` | `tree_sitter_find_similar_code` | simplify-agent, coder-agent |
| `mcp__tree_sitter__analyze_complexity` | `tree_sitter_analyze_complexity` | simplify-agent, coder-agent |

The routing itself (which tool for which need) is `pal-routing.md`, written
with bare tool names so it stays valid under both harnesses: `_shared` ships
as-is to OpenCode and is not rewritten. Any id appearing in a generated
surface (`plugins/10x/commands/`, `plugins/10x/agents/`) still needs a row:
the generator fails on any `mcp__` it cannot rewrite, so an id used in a new
command or agent must be added here first.

`plugins/10x/README.md` keeps the Claude Code form and is not rewritten: it
documents Claude Code's permission prefix (`mcp__pal__*`), which is a fact about
that harness rather than a tool call.

## Adding a server

Add one section per server, with every tool the plugin names. The rewrite is a
literal substitution, so a row must give the exact id as written in the source,
backticks excluded.
