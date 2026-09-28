# 10x

Plugin to make Claude Code a 10x more efficient

## Features

| Type | Name | What it does |
|---|---|---|
| Command | `/10x:manual` | What the plugin offers and where this project stands. Derives its catalogue from the files, so it cannot drift from this table |
| Command | `/10x:plan` | Steering documents: `init`, `status`, `add`, `rule`, `check`, `done`. Writes plans and contracts, never executes a phase |
| Command | `/10x:loop` | One plan-driven work turn: take a phase, implement, prove it with a mutation-checked gate, commit, stop. Never pushes |
| Command | `/10x:handoff` | Save or restore the thread of a phase interrupted mid-way (`--resume` to read it back) |
| Command | `/10x:check-conform` | Diagnose a repo against the engineering standard and report drift. Read-only |
| Command | `/10x:make-conform` | Apply the standard's remediations and open one PR. Modifies the repo |
| Command | `/10x:propose-probe` | Turn a confirmed conformance false negative into a draft new check |
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
| Agent | `conform-agent` | Audits a repo against the standard and dispatches remediation |
| Agent | `coder-agent`, `fixer-agent` | Non-trivial implementation; mechanical fully-specified edits |
| Agent | `tester-agent`, `docker-agent`, `documentation-agent` | Testing, Docker, and documentation delegates |

`/10x:manual` prints this catalogue from the plugin files themselves. When the two
disagree, the command is right: this table is prose and drifts, the frontmatter
does not.

Every artifact the plugin writes or reads in a target project (plans, reports,
briefs, steering docs) is catalogued in
`skills/_shared/references/artifacts.md`: path, writer, reader, format,
lifecycle.

## Harness support

What each shipped surface does under each harness. Every row names a file
under `commands/`, `agents/`, `skills/` or `hooks/`, and every such file has a
row: `scripts/check-harness-matrix.sh` fails CI otherwise, so this table cannot
silently fall behind the tree. Values:

- `supported`: consumed by the harness as written.
- `generated`: converted into the committed `opencode/` tree by
  `scripts/gen-opencode.sh`; the check confirms the generated file exists.
- `linked`: symlinked from source by `scripts/install-opencode.sh`, unmodified.
- `unsupported`: not delivered to that harness by this repo. MCP servers
  marked `unsupported` are not declared by the installer (`--mcp` declares
  `pal` only); the skills still name their tools in Claude Code's id form.

Hooks are Claude Code's PostToolUse shell commands, declared in
`hooks/hooks.json`. OpenCode has a JS plugin API instead, so the generated
`opencode/plugins/10x-hooks.js` (linked by the installer) runs those same
scripts on its `tool.execute.after` event for `write` and `edit`, rebuilding
the payload they read, and appends what a hook reports to the tool output the
model sees. One implementation, two harnesses; `scripts/test-hooks.sh` drives
both. The model reads a hook's verdict either way, but under OpenCode it is a
note appended to the tool result rather than a separate hook message.

| Surface | Name | Claude Code | OpenCode |
|---|---|---|---|
| Command | `audit-ui` | supported | generated (`/10x-audit-ui`) |
| Command | `check-conform` | supported | generated (`/10x-check-conform`) |
| Command | `design-handoff` | supported | generated (`/10x-design-handoff`) |
| Command | `evaluate` | supported | generated (`/10x-evaluate`) |
| Command | `handoff` | supported | generated (`/10x-handoff`) |
| Command | `loop` | supported | generated (`/10x-loop`) |
| Command | `make-conform` | supported | generated (`/10x-make-conform`) |
| Command | `manual` | supported | generated (`/10x-manual`) |
| Command | `plan` | supported | generated (`/10x-plan`) |
| Command | `propose-probe` | supported | generated (`/10x-propose-probe`) |
| Command | `tellme` | supported | generated (`/10x-tellme`) |
| Agent | `coder-agent` | supported | generated |
| Agent | `conform-agent` | supported | generated |
| Agent | `docker-agent` | supported | generated |
| Agent | `documentation-agent` | supported | generated |
| Agent | `fixer-agent` | supported | generated |
| Agent | `tester-agent` | supported | generated |
| Skill | `ci` | supported | linked |
| Skill | `commit` | supported | linked |
| Skill | `conform` | supported | linked |
| Skill | `design-system` | supported | linked |
| Skill | `docker` | supported | linked |
| Skill | `documentation-rules` | supported | linked |
| Skill | `lang-go` | supported | linked |
| Skill | `lang-html` | supported | linked |
| Skill | `lang-sql` | supported | linked |
| Skill | `lang-typescript` | supported | linked |
| Skill | `loop` | supported | linked |
| Skill | `makefile` | supported | linked |
| Skill | `manual` | supported | linked |
| Skill | `steering` | supported | linked |
| Skill | `testing` | supported | linked |
| Skill | `thinking` | supported | linked |
| Skill | `_shared` | supported | linked |
| Hook | `check-claude-md` | supported | supported (via `plugins/10x-hooks.js`) |
| Hook | `check-dashes` | supported | supported (via `plugins/10x-hooks.js`) |
| Hook | `check-refs` | supported | supported (via `plugins/10x-hooks.js`) |
| MCP | `pal` | supported | supported |
| MCP | `tree_sitter` | supported | unsupported |
| MCP | `context7` | supported | unsupported |

Agents under OpenCode also take their model from `opencode.json`, bound by
`scripts/install-opencode.sh --models` (see the repository README).

## Context cost per harness

What is always loaded into context before any skill or agent is invoked,
measured by `python3 scripts/check-skill-tokens.py --report` (`cl100k_base`
via `tiktoken==0.12.0`, same tokenizer as the budget check above). This is a
measurement, not a budget: it does not enforce a limit, and the numbers move
as skill descriptions and agent rosters change.

| Harness | Always loaded | What it is |
|---|---|---|
| Claude Code | 969 tokens | The 16 skill `description:` fields only; skill bodies load lazily on invocation. |
| OpenCode | 1,035 tokens | The same 16 descriptions, plus the generated `Read these skills first: ...` preamble line every agent declaring `skills:` carries in `opencode/agents/*.md`. |

OpenCode's fixed floor is about 7% above Claude Code's for this repo today:
66 tokens across the 6 generated agent preambles (`coder-agent` 17,
`conform-agent` 12, `fixer-agent` 12, `documentation-agent` 9,
`tester-agent` 9, `docker-agent` 7). Both numbers are small relative to the
skill-body budget above; optimizing this floor is not warranted by these
numbers and is deliberately out of scope here.

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
