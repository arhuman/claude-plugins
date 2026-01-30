---
name: global-project-manager
description: Task and project management in .claude/global-project/. Handles task lifecycle, status tracking, and optional S3 sync.
allowed-tools: Read, Write, Glob, Bash(jj *), Bash(git *), Bash(tree *), Bash(s4ync *), Bash(which *), Bash(make *), Bash(go *)
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
| "status report", "project status", "what's the state?" | Generate status report (see Status Reporting) |
| "list projects", "show all projects" | List all projects from S3 via `s4ync list` (requires S3 env vars) |
| Any work request (implement, fix, add, refactor...) | Auto-create task silently before starting (see Auto Task Creation) |

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

## Auto Task Creation

When the user makes a work request involving implementation, fixing, refactoring, or any significant change — **automatically create a task before starting work**, without asking for confirmation.

### Trigger patterns

Any request containing verbs like: `implement`, `fix`, `add`, `refactor`, `update`, `create`, `remove`, `migrate`, `optimize`, `write`, `build`, `integrate`, `change`...

### What to do

1. Infer title from the user's request (concise, action-based: "Fix login bug", "Add CSV export", "Refactor auth module")
2. Infer priority: `critical` if "urgent"/"blocker", `high` if "fix"/"bug", `medium` otherwise
3. Create `task-XXX.md` with `status: in_progress` and `started_at` = now
4. Create `task-XXX-history.md` with `created` + `status_change → in_progress` entries
5. Add `task_added | task-XXX` to `project_history.md`
6. **Do not announce the task creation** — proceed silently with the work
7. When work is done, complete the task (see Completing Tasks)

### Exceptions — do NOT auto-create a task when

- The request is a question, explanation, or analysis (no code change expected)
- A task for the same work already exists as `in_progress`
- The user explicitly says "no task", "skip tracking", or similar

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

### Status Reporting

When asked for a project status or report:
1. Read all `task-*.md` frontmatter (skip `-history.md` files)
2. Group by status: `in_progress`, `todo`/`backlog`, `done`, `cancelled`
3. For done tasks, check `completed_at` — flag those within the last 7 days as "completed this week"
4. Get versioning info using the Version Control procedure below
5. Output a concise markdown report:
   ```
   ## Project Status — {project shortname}

   **Branch**: {current branch/bookmark} | **Recent**: {latest commit summary}

   **In progress** (N)
   - task-XXX: title [priority]

   **Completed this week** (N)
   - task-XXX: title

   **Backlog** (N tasks)
   ```
6. If S3 env vars are present, sync the report alongside task files

## Version Control

Use this procedure whenever version/commit information is needed (status reports, project init, etc.):

1. **Check for jj first**: if `jj_repo: true` in `project.md` or `.jj/` directory exists:
   - Current bookmark/branch: `jj log -r @ --no-pager -T 'if(bookmarks, bookmarks, "detached")'`
   - Recent changes: `jj log --no-pager -l 5 -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"'`
2. **Fallback to git**: if no jj, check for `.git/` directory:
   - Current branch: `git branch --show-current`
   - Recent commits: `git log --oneline -5`
3. **Neither**: skip versioning info in output

## Resolving s4ync Binary

Use this procedure whenever `s4ync` is needed:

1. Check PATH: `which s4ync` → use it if found
2. Look for pre-built binary in plugin cache:
   ```
   ~/.claude/plugins/cache/arhuman-marketplace/global-project-manager/*/tools/s4ync/s4ync
   ```
   Use `Glob` to find it; if found, use that path as `S4YNC_BIN`
3. If binary not found, build from source:
   - Find source dir via Glob: `~/.claude/plugins/cache/arhuman-marketplace/global-project-manager/*/tools/s4ync/`
   - Run `make build` in that directory
   - Use the resulting binary as `S4YNC_BIN`
4. If source not found either, inform the user that s4ync could not be found and suggest `make install` in the plugin's `tools/s4ync/` directory

## Listing All Projects

When asked to list all projects (not just the current one):

If S3 env vars exist (`MINIO_ENDPOINT`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`):
- Resolve `S4YNC_BIN` using the procedure above
- Run `$S4YNC_BIN list`

If no S3:
- S3 is the only cross-project registry; explain that `list projects` requires S3 to be configured

## S3 Sync (Optional)

If env vars exist (`MINIO_ENDPOINT`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`):
- Resolve `S4YNC_BIN` using the procedure above
- Sync to `s3://global_projects/{shortname}/`
- Update `last_sync` in `project.md`

## Schema Details

**Only read `references/schema.md` when creating new files.** Contains field definitions, format examples, ID generation rules.
