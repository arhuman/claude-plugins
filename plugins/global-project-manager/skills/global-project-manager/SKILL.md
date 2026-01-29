---
name: global-project-manager
description: Task and project management in .claude/global-project/. Handles task lifecycle, status tracking, and optional S3 sync.
allowed-tools: Read, Write, Glob, Bash(jj *), Bash(git *), Bash(tree *)
---

# Global Task Manager

Manages tasks in `.claude/global-project/` with lightweight files + separate history. Auto-commits with jj on completion.

## Quick Reference

| User Says | Action |
|-----------|--------|
| "new task", "start work on..." | Create task-XXX.md, ask title/priority |
| "mark done", "finished", "complete" | status→done, jj commit, update history |
| "list tasks", "what's pending?" | Show in_progress, then todo |
| "this week", "recent" | Filter completed_at last 7 days |
| "cancel task X" | status→cancelled, update history |
| "current task" | Show in_progress tasks |

## File Structure

```
.claude/global-project/
├── project.md              # Metadata (read references/schema.md for format)
├── project_history.md      # Append-only log
├── task-001.md         # Current state only
├── task-001-history.md # All changes (saves tokens)
└── ...
```

**Statuses**: `backlog` | `todo` | `in_progress` | `done` | `cancelled`
**Priorities**: `low` | `medium` | `high` | `critical`

## Workflow

### First Use in Project

If `.claude/global-project/` missing:
1. Create `.claude/global-project/`
2. Create `project.md` (read `references/schema.md` for full format):
   - `shortname`: kebab-case from directory name
   - `git_repo`: from `.git/config` if exists
   - `jj_repo: true` if `.jj/` directory exists
3. Create `project_history.md` with `created` entry

### Creating Tasks

1. Read existing `task-*.md` to get next sequential ID (task-001, task-002...)
2. Create `task-XXX.md` with frontmatter (see references/schema.md when creating files)
3. Create `task-XXX-history.md` with `created` entry
4. Add `task_added | task-XXX` to `project_history.md`
5. If jj repo: run `jj new -m "task-XXX: {title}"`

**Optional**: Create detailed files in `.claude/global-project/task-XXX/`:
- `overview.md`: objectives, success criteria
- `approach.md`: methodology
- `checklist.md`: actionable steps
- `notes.md`: insights during execution

### Updating Tasks

1. Edit `task-XXX.md` frontmatter
2. Append to `task-XXX-history.md`: `{timestamp} | {event} | {details}`
   - Events: `status_change`, `priority_change`, `note`, `title_change`
3. Update timestamps:
   - `started_at`: when → `in_progress`
   - `completed_at`: when → `done` or `cancelled`

### Completing Tasks

When status → `done` or `cancelled`:
1. Set `completed_at` timestamp
2. Update histories
3. If `jj_repo: true`: `jj new -m "{task_title}"`
4. Add entry to `project_history.md`

### Listing Tasks

Read `task-*.md` files (ignore `-history.md`), filter by status/date.

## S3 Sync (Optional)

If env vars exist (`MINIO_ENDPOINT`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`):
- Sync to `s3://global_projects/{shortname}/`
- Update `last_sync` in `project.md`

## Schema Details

**Only read `references/schema.md` when creating new files.** Contains field definitions, format examples, ID generation rules.
