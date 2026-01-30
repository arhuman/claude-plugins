package sync_test

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/arhuman/s4ync/internal/storage"
	"github.com/arhuman/s4ync/internal/sync"
)

func TestEngine_DryRun(t *testing.T) {
	// Create temp directories
	localDir := t.TempDir()
	remoteDir := t.TempDir()

	// Create local file
	localFile := "project.md"
	localContent := []byte("---\nshortname: test\n---\n\nLocal content\n")
	if err := os.WriteFile(filepath.Join(localDir, localFile), localContent, 0644); err != nil {
		t.Fatalf("failed to create local file: %v", err)
	}

	local := storage.NewLocalStorage(localDir)
	remote := storage.NewLocalStorage(remoteDir) // Using local storage as mock
	pathMapper := storage.NewPathMapper("test")

	engine := sync.NewEngine(local, remote, pathMapper)

	// Build inventory
	inventory, err := sync.BuildInventory(local, remote, pathMapper, nil)
	if err != nil {
		t.Fatalf("BuildInventory failed: %v", err)
	}

	// Run sync in dry-run mode
	var output bytes.Buffer
	opts := &sync.Options{
		DryRun:  true,
		Verbose: true,
		Output:  &output,
	}

	result, err := engine.Sync(inventory, opts)
	if err != nil {
		t.Fatalf("Sync failed: %v", err)
	}

	// Verify file was not actually uploaded
	if _, err := os.Stat(filepath.Join(remoteDir, localFile)); !os.IsNotExist(err) {
		t.Error("dry-run should not create files")
	}

	// But should be reported as uploaded
	if len(result.Uploaded) != 1 {
		t.Errorf("expected 1 upload in result, got %d", len(result.Uploaded))
	}

	// Check output contains dry-run message
	if !bytes.Contains(output.Bytes(), []byte("[DRY RUN]")) {
		t.Error("output should contain [DRY RUN]")
	}
}

func TestEngine_Upload(t *testing.T) {
	localDir := t.TempDir()
	remoteDir := t.TempDir()

	// Create local file
	localFile := "project.md"
	localContent := []byte("---\nshortname: test\n---\n\nTest content\n")
	if err := os.WriteFile(filepath.Join(localDir, localFile), localContent, 0644); err != nil {
		t.Fatalf("failed to create local file: %v", err)
	}

	local := storage.NewLocalStorage(localDir)
	remote := storage.NewLocalStorage(remoteDir)
	pathMapper := storage.NewPathMapper("test")

	engine := sync.NewEngine(local, remote, pathMapper)

	inventory, err := sync.BuildInventory(local, remote, pathMapper, nil)
	if err != nil {
		t.Fatalf("BuildInventory failed: %v", err)
	}

	opts := &sync.Options{}
	result, err := engine.Sync(inventory, opts)
	if err != nil {
		t.Fatalf("Sync failed: %v", err)
	}

	if len(result.Uploaded) != 1 {
		t.Errorf("expected 1 upload, got %d", len(result.Uploaded))
	}

	// Verify file exists on remote
	remoteContent, err := os.ReadFile(filepath.Join(remoteDir, localFile))
	if err != nil {
		t.Fatalf("failed to read remote file: %v", err)
	}

	if !bytes.Equal(remoteContent, localContent) {
		t.Error("remote content doesn't match local")
	}
}

func TestEngine_Download(t *testing.T) {
	localDir := t.TempDir()
	remoteDir := t.TempDir()

	// Create remote file
	remoteFile := "project.md"
	remoteContent := []byte("---\nshortname: test\n---\n\nRemote content\n")
	if err := os.WriteFile(filepath.Join(remoteDir, remoteFile), remoteContent, 0644); err != nil {
		t.Fatalf("failed to create remote file: %v", err)
	}

	local := storage.NewLocalStorage(localDir)
	remote := storage.NewLocalStorage(remoteDir)
	pathMapper := storage.NewPathMapper("test")

	// Set last sync to far future so remote file appears newer
	lastSync := time.Now().Add(-time.Hour)
	inventory, err := sync.BuildInventory(local, remote, pathMapper, &lastSync)
	if err != nil {
		t.Fatalf("BuildInventory failed: %v", err)
	}

	engine := sync.NewEngine(local, remote, pathMapper)

	opts := &sync.Options{}
	result, err := engine.Sync(inventory, opts)
	if err != nil {
		t.Fatalf("Sync failed: %v", err)
	}

	if len(result.Downloaded) != 1 {
		t.Errorf("expected 1 download, got %d", len(result.Downloaded))
	}

	// Verify file exists locally
	localContent, err := os.ReadFile(filepath.Join(localDir, remoteFile))
	if err != nil {
		t.Fatalf("failed to read local file: %v", err)
	}

	if !bytes.Equal(localContent, remoteContent) {
		t.Error("local content doesn't match remote")
	}
}

func TestEngine_ForceUp(t *testing.T) {
	localDir := t.TempDir()
	remoteDir := t.TempDir()

	// Create files on both sides
	fileName := "project.md"
	localContent := []byte("local version")
	remoteContent := []byte("remote version")

	if err := os.WriteFile(filepath.Join(localDir, fileName), localContent, 0644); err != nil {
		t.Fatalf("failed to create local file: %v", err)
	}
	if err := os.WriteFile(filepath.Join(remoteDir, fileName), remoteContent, 0644); err != nil {
		t.Fatalf("failed to create remote file: %v", err)
	}

	local := storage.NewLocalStorage(localDir)
	remote := storage.NewLocalStorage(remoteDir)
	pathMapper := storage.NewPathMapper("test")

	// Set lastSync so both appear unchanged normally
	lastSync := time.Now().Add(time.Hour) // Future time
	inventory, err := sync.BuildInventory(local, remote, pathMapper, &lastSync)
	if err != nil {
		t.Fatalf("BuildInventory failed: %v", err)
	}

	engine := sync.NewEngine(local, remote, pathMapper)

	// Force upload
	opts := &sync.Options{ForceUp: true}
	result, err := engine.Sync(inventory, opts)
	if err != nil {
		t.Fatalf("Sync failed: %v", err)
	}

	if len(result.Uploaded) != 1 {
		t.Errorf("expected 1 upload with force-up, got %d", len(result.Uploaded))
	}

	// Verify remote now has local content
	finalRemote, _ := os.ReadFile(filepath.Join(remoteDir, fileName))
	if !bytes.Equal(finalRemote, localContent) {
		t.Error("force-up should overwrite remote with local")
	}
}

func TestEngine_ForceDown(t *testing.T) {
	localDir := t.TempDir()
	remoteDir := t.TempDir()

	// Create files on both sides
	fileName := "project.md"
	localContent := []byte("local version")
	remoteContent := []byte("remote version")

	if err := os.WriteFile(filepath.Join(localDir, fileName), localContent, 0644); err != nil {
		t.Fatalf("failed to create local file: %v", err)
	}
	if err := os.WriteFile(filepath.Join(remoteDir, fileName), remoteContent, 0644); err != nil {
		t.Fatalf("failed to create remote file: %v", err)
	}

	local := storage.NewLocalStorage(localDir)
	remote := storage.NewLocalStorage(remoteDir)
	pathMapper := storage.NewPathMapper("test")

	lastSync := time.Now().Add(time.Hour)
	inventory, err := sync.BuildInventory(local, remote, pathMapper, &lastSync)
	if err != nil {
		t.Fatalf("BuildInventory failed: %v", err)
	}

	engine := sync.NewEngine(local, remote, pathMapper)

	// Force download
	opts := &sync.Options{ForceDown: true}
	result, err := engine.Sync(inventory, opts)
	if err != nil {
		t.Fatalf("Sync failed: %v", err)
	}

	if len(result.Downloaded) != 1 {
		t.Errorf("expected 1 download with force-down, got %d", len(result.Downloaded))
	}

	// Verify local now has remote content
	finalLocal, _ := os.ReadFile(filepath.Join(localDir, fileName))
	if !bytes.Equal(finalLocal, remoteContent) {
		t.Error("force-down should overwrite local with remote")
	}
}

func TestEngine_TaskFilePath(t *testing.T) {
	localDir := t.TempDir()
	remoteDir := t.TempDir()

	// Create a task file locally
	taskFile := "task-001.md"
	taskContent := []byte("---\nid: task-001\n---\n\nTask content\n")
	if err := os.WriteFile(filepath.Join(localDir, taskFile), taskContent, 0644); err != nil {
		t.Fatalf("failed to create task file: %v", err)
	}

	local := storage.NewLocalStorage(localDir)
	remote := storage.NewLocalStorage(remoteDir)
	pathMapper := storage.NewPathMapper("test")

	inventory, err := sync.BuildInventory(local, remote, pathMapper, nil)
	if err != nil {
		t.Fatalf("BuildInventory failed: %v", err)
	}

	engine := sync.NewEngine(local, remote, pathMapper)

	opts := &sync.Options{}
	result, err := engine.Sync(inventory, opts)
	if err != nil {
		t.Fatalf("Sync failed: %v", err)
	}

	if len(result.Uploaded) != 1 {
		t.Errorf("expected 1 upload, got %d", len(result.Uploaded))
	}

	// Verify task file went to tasks/ subdirectory
	remoteTaskPath := filepath.Join(remoteDir, "tasks", taskFile)
	if _, err := os.Stat(remoteTaskPath); os.IsNotExist(err) {
		t.Errorf("task file should be uploaded to tasks/ subdirectory, checked: %s", remoteTaskPath)
	}
}

func TestResult_Summary(t *testing.T) {
	result := &sync.Result{
		Uploaded:   []string{"a.md", "b.md"},
		Downloaded: []string{"c.md"},
		Skipped:    []string{"d.md", "e.md", "f.md"},
		Conflicts:  []string{"g.md"},
		Errors:     []sync.SyncError{{Path: "h.md", Err: nil}},
	}

	summary := result.Summary()
	expected := "Uploaded: 2, Downloaded: 1, Skipped: 3, Conflicts: 1, Errors: 1"

	if summary != expected {
		t.Errorf("expected summary %q, got %q", expected, summary)
	}
}

func TestResult_HasErrors(t *testing.T) {
	result := &sync.Result{}

	if result.HasErrors() {
		t.Error("empty result should not have errors")
	}

	result.Errors = append(result.Errors, sync.SyncError{})

	if !result.HasErrors() {
		t.Error("result with errors should return true")
	}
}
