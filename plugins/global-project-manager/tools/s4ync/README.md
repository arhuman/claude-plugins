# S4YNC

S4YNC (pronounced "sync") is a bidirectional file synchronization tool that syncs the `.claude/global-project/` directory with a MinIO S3 bucket.

## Features

- Bidirectional sync between local filesystem and MinIO S3
- Timestamp-based decision matrix for determining sync direction
- Conflict resolution strategies: newest, local, remote, interactive
- History file merging with deduplication
- Atomic file operations (temp file + rename)
- Non-blocking errors (continues sync despite individual file failures)
- Dry-run mode for previewing changes
- Force upload/download options

## Installation

```bash
# Build from source
cd tools/s4ync
make build

# Or install to GOPATH/bin
make install
```

## Configuration

Set the following environment variables:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `MINIO_ENDPOINT` | Yes | - | MinIO server endpoint (e.g., `localhost:9000`) |
| `MINIO_ACCESS_KEY` | Yes | - | MinIO access key |
| `MINIO_SECRET_KEY` | Yes | - | MinIO secret key |
| `MINIO_SECURE` | No | `true` | Use HTTPS for MinIO connection |
| `MINIO_BUCKET` | No | `global_projects` | S3 bucket name |
| `PROJECT_PATH` | No | `.claude/global-project` | Path to project directory |

## Usage

```bash
# Auto-detect project in current directory or parent
s4ync

# Explicit project path
s4ync --path /path/to/project/.claude/global-project

# Preview changes without making them
s4ync --dry-run

# Force upload all files (ignore remote changes)
s4ync --force-up

# Force download all files (ignore local changes)
s4ync --force-down

# Conflict resolution strategies
s4ync --prefer-local      # Always use local on conflict
s4ync --prefer-remote     # Always use remote on conflict

# Verbose output
s4ync --verbose

# Show version
s4ync version
```

## Sync Algorithm

### Decision Matrix

| Local Modified | S3 Modified | Action |
|----------------|-------------|--------|
| After lastSync | After lastSync | CONFLICT |
| After lastSync | Before/Equal | UPLOAD |
| Before/Equal | After lastSync | DOWNLOAD |
| Before/Equal | Before/Equal | SKIP |
| Exists | Not exists | UPLOAD |
| Not exists | Exists | DOWNLOAD |

### First Sync

When `last_sync: null` in `project.md`:
1. Upload all local files to S3
2. Set `last_sync` to current timestamp
3. Log sync to `project_history.md`

### Path Mapping

```
Local: .claude/global-project/project.md
S3:    {shortname}/project.md

Local: .claude/global-project/task-001.md
S3:    {shortname}/tasks/task-001.md
```

### Conflict Resolution

For regular files:
- **newest**: Use file with latest modification time (default)
- **local**: Always prefer local version
- **remote**: Always prefer remote version

For history files (`*-history.md`):
- Merge both versions
- Sort by timestamp
- Deduplicate exact matches

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Partial failure (some files failed) |
| 2 | Configuration error |
| 3 | Critical error (cannot read project.md) |

## Development

```bash
# Run tests
make test

# Run tests with coverage
make test-coverage

# Format code
make fmt

# Run linter
make lint
```

## License

MIT License
