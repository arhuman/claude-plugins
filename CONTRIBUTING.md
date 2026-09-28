# Contributing

## Plugin structure

```
plugins/{name}/
├── .claude-plugin/plugin.json
├── agents/{agent-name}.md
├── skills/{skill-name}/
│   ├── SKILL.md
│   ├── references/   # docs loaded by Claude as needed
│   ├── scripts/      # executable code
│   └── assets/       # output files (templates, images, fonts)
└── README.md         # plugin-level only, not inside skills/
```

## Writing skills

### Frontmatter

All fields are optional except `description` (recommended). Valid fields: [full spec](https://code.claude.com/docs/en/skills#frontmatter-reference).

| Field | Description |
|-------|-------------|
| `name` | Skill name and `/slash-command`. Defaults to directory name. |
| `description` | What the skill does and when to use it. Primary trigger mechanism. |
| `allowed-tools` | Tools Claude can use without asking permission when this skill is active. |
| `disable-model-invocation` | Set `true` to prevent Claude from auto-loading; user-invocable only. |
| `user-invocable` | Set `false` to hide from `/` menu; Claude-only invocation. |
| `argument-hint` | Hint shown in autocomplete (e.g. `[issue-number]`). |
| `model` | Model to use when this skill is active. |
| `context` | Set `fork` to run in an isolated subagent. |
| `agent` | Subagent type when `context: fork` is set. |
| `hooks` | Hooks scoped to this skill's lifecycle. |

Do not add custom fields (`license`, `metadata`, `triggers`, `version`, `author`, etc.).

The `description` is the sole auto-trigger mechanism. Include trigger and anti-trigger context there, not in the body.

### SKILL.md body

- Optimize for correct AI behavior per token.
- Keep under 500 lines and inside `scripts/skill-token-budget.json`.
- Keep text only when it changes a decision, constrains an action, defines an output, or verifies completion.
- Move long phase detail to `references/` files and say when to read each reference.
- Do not repeat content that is already in `references/` files or another owning skill.
- No "When to Use This Skill" section in the body.

### Forbidden files inside `skills/`

Do not create auxiliary documentation files inside a skill directory:

- `README.md`
- `CHANGELOG.md`
- `INSTALLATION_GUIDE.md`
- `QUICK_REFERENCE.md`

### Resource directories

| Directory | Purpose |
|-----------|---------|
| `references/` | Docs and guides loaded into context as needed |
| `scripts/` | Executable code run without loading into context |
| `assets/` | Files used in output (templates, fonts, images) |

Use `references/`, not `resources/`.

## Checks

Run before every commit:

```bash
make check
```

It runs the same static checks as CI, in the same order, and stops on the first
failure. `make help` lists every target.

Two checks degrade instead of failing when a python module is missing, and say
so on stdout: the token budget needs `tiktoken`, the frontmatter parse prefers
`pyyaml` (it falls back to a narrower grep without it). CI installs both before
running `make check`, so a local `SKIP` line never means CI skipped it too.

```bash
python3 -m pip install tiktoken==0.12.0 pyyaml
```

After changing anything under `plugins/10x/commands/` or `plugins/10x/agents/`,
regenerate the OpenCode tree in the same commit; never edit `opencode/` by hand.

```bash
make gen
```

An agent's `model:` is a tier word (`opus`, `sonnet`, `haiku`), never a model
id: Claude Code reads the tier natively and `install-opencode.sh --models`
binds it per user from `scripts/opencode-models.json`. Every agent must declare
one. A command may declare one too, but it only reaches Claude Code: OpenCode
cannot carry a command model outside the command definition. A new tier word
needs a row in that file.

## Version control

This repo uses [jj](https://github.com/martinvonz/jj) (Jujutsu) with git colocated.
