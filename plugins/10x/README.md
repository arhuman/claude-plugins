# 10x

Plugin to make Claude Code a 10x more efficient

## Features

| Type | Name | What it does |
|---|---|---|
| Command | `/10x:doc` | What the plugin offers and where this project stands. Derives its catalogue from the files, so it cannot drift from this table |
| Command | `/10x:plan` | Steering documents: `init`, `status`, `add`, `rule`, `check`, `done`. Writes plans and contracts, never executes a phase |
| Command | `/10x:loop` | One plan-driven work turn: take a phase, implement, prove it with a mutation-checked gate, commit, stop. Never pushes |
| Command | `/10x:handoff` | Save or restore the thread of a phase interrupted mid-way (`--resume` to read it back) |
| Command | `/10x:check_conform` | Diagnose a repo against the engineering standard and report drift. Read-only |
| Command | `/10x:make_conform` | Apply the standard's remediations and open one PR. Modifies the repo |
| Command | `/10x:propose_probe` | Turn a confirmed conformance false negative into a draft new check |
| Command | `/10x:tellme` | Read-only technical Q&A and architectural guidance |
| Command | `/10x:evaluate` | Multi-model comparison of an answer via PAL, synthesized into one doc |
| Skill | `steering` | Steering documentation: scaffold, execution plan, UX contract, consistency audit, ownership |
| Skill | `loop` | The work loop and its verification gate (mutation check, dependency surface, goldens) |
| Skill | `manual` | The plugin's own catalogue and glossary, derived from the files |
| Skill | `conform` | Drift from the engineering standard: `standard.yml` plus the portable runner |
| Skill | `design-system` | UX/frontend design system for SSR + HTMX UIs: quality grid, CSS token contract, component and accessibility rules, UI CI guards |
| Skill | `ci` | GitHub Actions CI/CD, release automation, coverage gates |
| Skill | `commit` | jj (Jujutsu) commit mechanics, hardened against recurring jj/commitlint failures |
| Skill | `thinking` | Thinking guidelines to reduce common coding mistakes |
| Skill | `docker`, `makefile`, `documentation-rules`, `testing` | Domain best practices (Docker, Makefiles, docs, testing) |
| Skill | `lang-go`, `lang-typescript`, `lang-html`, `lang-sql` | Per-language coding standards |
| Skill | `grill-with-docs` | Plan stress-testing against the documented domain model |
| Agent | `conform-agent` | Audits a repo against the standard and dispatches remediation |
| Agent | `coder-agent`, `fixer-agent` | Non-trivial implementation; mechanical fully-specified edits |
| Agent | `tester-agent`, `docker-agent`, `documentation-agent` | Testing, Docker, and documentation delegates |

`/10x:doc` prints this catalogue from the plugin files themselves. When the two
disagree, the command is right: this table is prose and drifts, the frontmatter
does not.

Every artifact the plugin writes or reads in a target project (plans, reports,
briefs, steering docs) is catalogued in
`skills/_shared/references/artifacts.md`: path, writer, reader, format,
lifecycle.

## Prerequisites

The plugin's skills and agents rely on three MCP servers. None are bundled: bundling would start duplicate server instances (and duplicate tool schemas) for users who already register them globally. Register them once in `~/.claude.json` under `mcpServers`:

```json
"tree_sitter": {
  "type": "stdio",
  "command": "uvx",
  "args": ["mcp-server-tree-sitter"]
},
"context7": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@upstash/context7-mcp"]
}
```

Requirements: [uv](https://docs.astral.sh/uv/) for `mcp-server-tree-sitter`, [Node.js](https://nodejs.org/) with `npx` for `context7`, and the [PAL MCP server](https://github.com/BeehiveInnovations/pal-mcp-server) (setup below; path is user-specific).

### PAL setup

PAL is not on PyPI yet, so it must be installed manually:

```bash
git clone https://github.com/BeehiveInnovations/pal-mcp-server
cd pal-mcp-server
python -m venv .pal_venv && source .pal_venv/bin/activate
pip install -e .
```

Then register it in `~/.claude.json` under `mcpServers`:

```json
"pal": {
  "type": "stdio",
  "command": "/path/to/pal-mcp-server/.pal_venv/bin/python",
  "args": ["/path/to/pal-mcp-server/server.py"]
}
```

The plugin pre-authorizes all PAL tools (`mcp__pal__*`) so you won't be prompted on each use.

### PAL model configuration for /evaluate

The `/evaluate` command uses three external models alongside Claude (see `commands/evaluate.md`, the source of truth):

| Model | Provider | Requirement |
|---|---|---|
| `google/gemini-3.1-pro-preview` | OpenRouter | `OPENROUTER_API_KEY` in PAL `.env` |
| `openai/gpt-5.3-codex` | OpenRouter | `OPENROUTER_API_KEY` in PAL `.env` |
| `deepseek/deepseek-v4-pro-0813` | OpenRouter | `OPENROUTER_API_KEY` in PAL `.env` |

**OpenRouter**: set in `pal-mcp-server/.env`:
```bash
OPENROUTER_API_KEY=your_openrouter_api_key_here
```

All three run through OpenRouter, so one key covers them. A provider that is
unavailable is skipped and the omission noted in the final document, rather than
failing the run.

## Installation

In claude code

```bash
/plugin marketplace add arhuman/claude-plugins
/plugin install 10x
```

## Permissions

Claude Code prompts for tool permissions on first use (file writes, `jj`/`git`/`make`/`docker` commands, MCP tools). The plugin pre-authorizes the PAL tools (`mcp__pal__*`); everything else follows your session permission settings.

## Agent names

Installed agents are namespaced by plugin: reference them as `10x:coder-agent`, `10x:tester-agent`, `10x:docker-agent`, `10x:documentation-agent` when more than one plugin provides similarly named agents.

## Inspiration

* [Jeffallan/claude-skills](https://github.com/Jeffallan/claude-skills): golang-pro and other excellent skills
* [obra/superpowers](https://github.com/obra/superpowers) by Jesse Vincent (@obra): TDD Iron Laws and Testing Anti-Patterns (MIT License)

## Licence

MIT License - see LICENSE file for details
