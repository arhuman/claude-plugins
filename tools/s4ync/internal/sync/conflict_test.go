package sync_test

import (
	"strings"
	"testing"
	"time"

	"github.com/arhuman/s4ync/internal/storage"
	"github.com/arhuman/s4ync/internal/sync"
)

func TestConflictResolver_Newest(t *testing.T) {
	resolver := sync.NewConflictResolver(sync.StrategyNewest, false)

	olderTime := time.Date(2026, 1, 29, 10, 0, 0, 0, time.UTC)
	newerTime := time.Date(2026, 1, 29, 12, 0, 0, 0, time.UTC)

	entry := sync.FileEntry{
		RelPath: "task-001.md",
		LocalInfo: &storage.FileInfo{
			Path:    "task-001.md",
			ModTime: newerTime,
			Size:    100,
		},
		RemoteInfo: &storage.FileInfo{
			Path:    "task-001.md",
			ModTime: olderTime,
			Size:    100,
		},
	}

	resolution, err := resolver.Resolve(entry, []byte("local"), []byte("remote"), nil)
	if err != nil {
		t.Fatalf("Resolve failed: %v", err)
	}

	if !resolution.UseLocal {
		t.Error("expected to use local (newer)")
	}
	if resolution.UseRemote {
		t.Error("expected not to use remote (older)")
	}
}

func TestConflictResolver_Local(t *testing.T) {
	resolver := sync.NewConflictResolver(sync.StrategyLocal, false)

	baseTime := time.Now()
	entry := sync.FileEntry{
		RelPath: "task-001.md",
		LocalInfo: &storage.FileInfo{
			Path:    "task-001.md",
			ModTime: baseTime,
			Size:    100,
		},
		RemoteInfo: &storage.FileInfo{
			Path:    "task-001.md",
			ModTime: baseTime.Add(time.Hour), // Remote is newer
			Size:    100,
		},
	}

	resolution, err := resolver.Resolve(entry, []byte("local"), []byte("remote"), nil)
	if err != nil {
		t.Fatalf("Resolve failed: %v", err)
	}

	if !resolution.UseLocal {
		t.Error("StrategyLocal should always use local")
	}
}

func TestConflictResolver_Remote(t *testing.T) {
	resolver := sync.NewConflictResolver(sync.StrategyRemote, false)

	baseTime := time.Now()
	entry := sync.FileEntry{
		RelPath: "task-001.md",
		LocalInfo: &storage.FileInfo{
			Path:    "task-001.md",
			ModTime: baseTime.Add(time.Hour), // Local is newer
			Size:    100,
		},
		RemoteInfo: &storage.FileInfo{
			Path:    "task-001.md",
			ModTime: baseTime,
			Size:    100,
		},
	}

	resolution, err := resolver.Resolve(entry, []byte("local"), []byte("remote"), nil)
	if err != nil {
		t.Fatalf("Resolve failed: %v", err)
	}

	if !resolution.UseRemote {
		t.Error("StrategyRemote should always use remote")
	}
}

func TestConflictResolver_HistoryFileMerge(t *testing.T) {
	resolver := sync.NewConflictResolver(sync.StrategyNewest, false)

	entry := sync.FileEntry{
		RelPath: "task-001-history.md",
		LocalInfo: &storage.FileInfo{
			Path:    "task-001-history.md",
			ModTime: time.Now(),
			Size:    100,
		},
		RemoteInfo: &storage.FileInfo{
			Path:    "task-001-history.md",
			ModTime: time.Now(),
			Size:    100,
		},
	}

	localHistory := `# Project History

- 2026-01-29T10:00:00Z | created
- 2026-01-29T12:00:00Z | status_change | backlog -> todo
`

	remoteHistory := `# Project History

- 2026-01-29T10:00:00Z | created
- 2026-01-29T11:00:00Z | note | Started work
`

	resolution, err := resolver.Resolve(entry, []byte(localHistory), []byte(remoteHistory), nil)
	if err != nil {
		t.Fatalf("Resolve failed: %v", err)
	}

	if resolution.Merged == nil {
		t.Fatal("expected merged content for history file")
	}

	merged := string(resolution.Merged)

	// Should contain all three entries (deduplicated)
	if !strings.Contains(merged, "created") {
		t.Error("merged should contain 'created' entry")
	}
	if !strings.Contains(merged, "note") {
		t.Error("merged should contain 'note' entry")
	}
	if !strings.Contains(merged, "status_change") {
		t.Error("merged should contain 'status_change' entry")
	}

	// Should be sorted by timestamp
	createdIdx := strings.Index(merged, "10:00:00Z")
	noteIdx := strings.Index(merged, "11:00:00Z")
	statusIdx := strings.Index(merged, "12:00:00Z")

	if createdIdx > noteIdx || noteIdx > statusIdx {
		t.Error("entries should be sorted by timestamp")
	}
}

func TestConflictResolver_BackupPath(t *testing.T) {
	resolver := sync.NewConflictResolver(sync.StrategyLocal, true) // backup enabled

	baseTime := time.Now()
	entry := sync.FileEntry{
		RelPath: "task-001.md",
		LocalInfo: &storage.FileInfo{
			Path:    "task-001.md",
			ModTime: baseTime,
			Size:    100,
		},
		RemoteInfo: &storage.FileInfo{
			Path:    "task-001.md",
			ModTime: baseTime,
			Size:    100,
		},
	}

	resolution, err := resolver.Resolve(entry, []byte("local"), []byte("remote"), nil)
	if err != nil {
		t.Fatalf("Resolve failed: %v", err)
	}

	if resolution.BackupPath == "" {
		t.Error("expected backup path when backup is enabled")
	}

	if !strings.HasPrefix(resolution.BackupPath, "task-001.conflict-") {
		t.Errorf("unexpected backup path format: %s", resolution.BackupPath)
	}

	if !strings.HasSuffix(resolution.BackupPath, ".md") {
		t.Error("backup path should end with .md")
	}
}
