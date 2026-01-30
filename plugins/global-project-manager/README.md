# Global Project Manager

Claude Code plugin for centralized task and project management.

## Features

- Task creation/modification with timestamped statuses
- Multi-project tracking with separate history
- Optional S3/Minio synchronization
- Local storage in `.claude/global-project/`

## Installation

In claude code

```bash
/plugin marketplace add arhuman/claude-plugin
/plugin install global-project-manager
```

## Permissions

The plugin automatically requests minimal permissions when first used:
- **Read/Write** access to `.claude/global-project/` (for task storage)
- **Read** access to project directory (for context)
- **Bash** commands for `jj` and `git` (if using version control)

These permissions are pre-declared in the plugin via `allowed-tools` frontmatter, reducing permission prompts during normal operation. You'll be asked to approve these on first use in each project.

## Task Statuses

| Status | Description |
|--------|-------------|
| `backlog` | Future idea, not planned |
| `todo` | Planned, ready |
| `in_progress` | In progress |
| `done` | Completed |
| `cancelled` | Cancelled |

## Priorities

`low`, `medium`, `high`, `critical`

## File Structure

```
.claude/global-project/
├── project.md              # Project metadata
├── project_history.md      # Project history
├── task-001.md         # Task
├── task-001-history.md # Task history
└── ...
```

## Environment Variables

The plugin loads `~/.claude/.env` automatically if present. Use this file to configure S3/Minio sync credentials:

```bash
MINIO_ENDPOINT=your-minio-endpoint
MINIO_ACCESS_KEY=your-access-key
MINIO_SECRET_KEY=your-secret-key
```

When these variables are set, tasks are synced to `s3://global_projects/{project-shortname}/`.

## Licence

MIT License - see LICENSE file for details
