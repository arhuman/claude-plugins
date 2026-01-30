package sync_test

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/arhuman/s4ync/internal/storage"
	"github.com/arhuman/s4ync/internal/sync"
)

func TestBuildInventory(t *testing.T) {
	// Create temp directories for local storage
	localDir := t.TempDir()

	// Create test files locally
	localFiles := []string{
		"project.md",
		"project_history.md",
		"task-001.md",
	}

	for _, f := range localFiles {
		path := filepath.Join(localDir, f)
		if err := os.WriteFile(path, []byte("test content"), 0644); err != nil {
			t.Fatalf("failed to create test file: %v", err)
		}
	}

	local := storage.NewLocalStorage(localDir)

	// Create a mock remote storage with some overlapping files
	remoteDir := t.TempDir()
	remote := storage.NewLocalStorage(remoteDir)

	// Simulate remote files (using local storage as mock)
	// Remote has project.md and a task-002.md that doesn't exist locally
	if err := os.WriteFile(filepath.Join(remoteDir, "project.md"), []byte("remote"), 0644); err != nil {
		t.Fatalf("failed to create remote file: %v", err)
	}
	if err := os.WriteFile(filepath.Join(remoteDir, "task-002.md"), []byte("remote task"), 0644); err != nil {
		t.Fatalf("failed to create remote file: %v", err)
	}

	pathMapper := storage.NewPathMapper("test")
	lastSync := time.Now().Add(-1 * time.Hour)

	// Note: This test is limited because we're using local storage for remote
	// In real usage, the path mapper would translate paths properly
	inventory, err := sync.BuildInventory(local, remote, pathMapper, &lastSync)
	if err != nil {
		t.Fatalf("BuildInventory failed: %v", err)
	}

	if inventory.LastSync != &lastSync {
		t.Error("LastSync not set correctly")
	}

	// Verify we have files from both sides
	if len(inventory.Files) == 0 {
		t.Error("expected files in inventory")
	}
}

func TestInventory_Stats(t *testing.T) {
	baseTime := time.Now()

	inventory := &sync.Inventory{
		LastSync: &baseTime,
		Files: []sync.FileEntry{
			{
				RelPath:   "local-only.md",
				LocalInfo: &storage.FileInfo{Path: "local-only.md"},
			},
			{
				RelPath:    "remote-only.md",
				RemoteInfo: &storage.FileInfo{Path: "remote-only.md"},
			},
			{
				RelPath:    "both.md",
				LocalInfo:  &storage.FileInfo{Path: "both.md"},
				RemoteInfo: &storage.FileInfo{Path: "both.md"},
			},
			{
				RelPath:    "both2.md",
				LocalInfo:  &storage.FileInfo{Path: "both2.md"},
				RemoteInfo: &storage.FileInfo{Path: "both2.md"},
			},
		},
	}

	localOnly, remoteOnly, both := inventory.Stats()

	if localOnly != 1 {
		t.Errorf("expected 1 local-only, got %d", localOnly)
	}
	if remoteOnly != 1 {
		t.Errorf("expected 1 remote-only, got %d", remoteOnly)
	}
	if both != 2 {
		t.Errorf("expected 2 both, got %d", both)
	}
}

func TestInventory_FilterFunctions(t *testing.T) {
	inventory := &sync.Inventory{
		Files: []sync.FileEntry{
			{RelPath: "local1.md", LocalInfo: &storage.FileInfo{}},
			{RelPath: "local2.md", LocalInfo: &storage.FileInfo{}},
			{RelPath: "remote.md", RemoteInfo: &storage.FileInfo{}},
			{RelPath: "both.md", LocalInfo: &storage.FileInfo{}, RemoteInfo: &storage.FileInfo{}},
		},
	}

	localOnly := inventory.LocalOnlyFiles()
	if len(localOnly) != 2 {
		t.Errorf("expected 2 local-only files, got %d", len(localOnly))
	}

	remoteOnly := inventory.RemoteOnlyFiles()
	if len(remoteOnly) != 1 {
		t.Errorf("expected 1 remote-only file, got %d", len(remoteOnly))
	}

	both := inventory.BothSidesFiles()
	if len(both) != 1 {
		t.Errorf("expected 1 both-sides file, got %d", len(both))
	}
}
