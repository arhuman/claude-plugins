# 10xCoder

Plugin to make Claude Code a 10x Coder

## Features


## Prerequisites

The plugin installs MCP servers that require:

- [uv](https://docs.astral.sh/uv/) — for `mcp-server-tree-sitter` (run via `uvx`)
- [Node.js](https://nodejs.org/) with `npx` — for `context7`
- [PAL MCP server](https://github.com/BeehiveInnovations/pal-mcp-server) — must be installed and registered globally in `~/.claude.json` (not bundled, path is user-specific)

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

The `/evaluate` command uses three external models alongside Claude:

| Model | Provider | Requirement |
|---|---|---|
| `google/gemini-2.5-pro` | OpenRouter | `OPENROUTER_API_KEY` in PAL `.env` |
| `local-mistral` | Ollama | `mistral-small:24b-instruct-2501-q4_K_M` pulled |
| `local-qwen` | Ollama | Qwen model pulled and registered (see below) |

**OpenRouter** — set in `pal-mcp-server/.env`:
```bash
OPENROUTER_API_KEY=your_openrouter_api_key_here
```

**Ollama local models** — register your installed Qwen model in `conf/custom_models.json` inside the PAL repo. The `/evaluate` command expects a `local-qwen` alias:

```json
{
  "model_name": "qwen3.5:35b",
  "aliases": ["local-qwen", "qwen3"],
  "context_window": 32768,
  "max_output_tokens": 16384,
  "supports_extended_thinking": true,
  "supports_json_mode": true,
  "supports_function_calling": true,
  "supports_images": false,
  "max_image_size_mb": 0.0,
  "description": "Qwen 3.5 35B via Ollama - 32K context window, thinking support",
  "intelligence_score": 15
}
```

Replace `qwen3.5:35b` with whichever Qwen model you have pulled (`ollama list`). The `local-mistral` alias is pre-registered and maps to `mistral-small:24b-instruct-2501-q4_K_M`.

## Installation

In claude code

```bash
/plugin marketplace add arhuman/claude-plugin
/plugin install 10xcoder 
```

## Permissions

The plugin automatically requests minimal permissions when first used:
- **Read/Write** access to `.claude/global-project/` (for task storage)
- **Read** access to project directory (for context)
- **Bash** commands for `jj` and `git` (if using version control)

These permissions are pre-declared in the plugin via `allowed-tools` frontmatter, reducing permission prompts during normal operation. You'll be asked to approve these on first use in each project.

## Inspiration

* [Jeffallan/claude-skills](https://github.com/Jeffallan/claude-skills) — golang-pro and other excellent skills
* [obra/superpowers](https://github.com/obra/superpowers) by Jesse Vincent (@obra) — TDD Iron Laws and Testing Anti-Patterns (MIT License)

## Licence

MIT License - see LICENSE file for details
