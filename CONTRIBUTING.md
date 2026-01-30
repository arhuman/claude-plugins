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

All fields are optional except `description` (recommended). Valid fields — [full spec](https://code.claude.com/docs/en/skills#frontmatter-reference):

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

The `description` is the sole auto-trigger mechanism. Include all "when to use" context there, not in the body.

### SKILL.md body

- Keep under 500 lines.
- Move detailed reference material to `references/` files, link from SKILL.md.
- Do not repeat content that is already in `references/` files.
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

## Version control

This repo uses [jj](https://github.com/martinvonz/jj) (Jujutsu) with git colocated.
