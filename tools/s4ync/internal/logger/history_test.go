package logger_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/arhuman/s4ync/internal/logger"
)

func TestHistoryLogger_LogSyncSuccess(t *testing.T) {
	tmpDir := t.TempDir()

	l := logger.NewHistoryLogger(tmpDir)

	if err := l.LogSyncSuccess(5, 3, 0); err != nil {
		t.Fatalf("LogSyncSuccess failed: %v", err)
	}

	// Read and verify
	content, err := os.ReadFile(l.FilePath())
	if err != nil {
		t.Fatalf("failed to read history file: %v", err)
	}

	contentStr := string(content)

	if !strings.Contains(contentStr, "# Project History") {
		t.Error("expected history header")
	}
	if !strings.Contains(contentStr, "synced") {
		t.Error("expected 'synced' event")
	}
	if !strings.Contains(contentStr, "uploaded: 5") {
		t.Error("expected 'uploaded: 5'")
	}
	if !strings.Contains(contentStr, "downloaded: 3") {
		t.Error("expected 'downloaded: 3'")
	}
}

func TestHistoryLogger_LogSyncFailure(t *testing.T) {
	tmpDir := t.TempDir()

	l := logger.NewHistoryLogger(tmpDir)

	if err := l.LogSyncFailure("S3 connection timeout"); err != nil {
		t.Fatalf("LogSyncFailure failed: %v", err)
	}

	content, err := os.ReadFile(l.FilePath())
	if err != nil {
		t.Fatalf("failed to read history file: %v", err)
	}

	contentStr := string(content)

	if !strings.Contains(contentStr, "sync_failed") {
		t.Error("expected 'sync_failed' event")
	}
	if !strings.Contains(contentStr, "S3 connection timeout") {
		t.Error("expected failure reason")
	}
}

func TestHistoryLogger_AppendMultiple(t *testing.T) {
	tmpDir := t.TempDir()

	l := logger.NewHistoryLogger(tmpDir)

	// Append multiple entries
	if err := l.AppendEntry("event1", "details1"); err != nil {
		t.Fatalf("first append failed: %v", err)
	}
	if err := l.AppendEntry("event2", "details2"); err != nil {
		t.Fatalf("second append failed: %v", err)
	}

	content, err := os.ReadFile(l.FilePath())
	if err != nil {
		t.Fatalf("failed to read history file: %v", err)
	}

	contentStr := string(content)

	// Both entries should be present
	if !strings.Contains(contentStr, "event1") {
		t.Error("expected event1")
	}
	if !strings.Contains(contentStr, "event2") {
		t.Error("expected event2")
	}

	// Count entry lines
	lines := strings.Split(contentStr, "\n")
	entryCount := 0
	for _, line := range lines {
		if strings.HasPrefix(line, "- ") {
			entryCount++
		}
	}

	if entryCount != 2 {
		t.Errorf("expected 2 entries, got %d", entryCount)
	}
}

func TestHistoryLogger_ExistingFile(t *testing.T) {
	tmpDir := t.TempDir()

	// Create existing history file
	existingContent := "# Project History\n\n- 2026-01-29T10:00:00Z | created\n"
	historyPath := filepath.Join(tmpDir, "project_history.md")
	if err := os.WriteFile(historyPath, []byte(existingContent), 0644); err != nil {
		t.Fatalf("failed to create existing file: %v", err)
	}

	l := logger.NewHistoryLogger(tmpDir)

	if err := l.AppendEntry("synced", "uploaded: 1"); err != nil {
		t.Fatalf("append failed: %v", err)
	}

	content, err := os.ReadFile(historyPath)
	if err != nil {
		t.Fatalf("failed to read history file: %v", err)
	}

	contentStr := string(content)

	// Both old and new entries should be present
	if !strings.Contains(contentStr, "created") {
		t.Error("expected original 'created' entry")
	}
	if !strings.Contains(contentStr, "synced") {
		t.Error("expected new 'synced' entry")
	}
}

func TestHistoryLogger_WithConflicts(t *testing.T) {
	tmpDir := t.TempDir()

	l := logger.NewHistoryLogger(tmpDir)

	if err := l.LogSyncSuccess(2, 1, 3); err != nil {
		t.Fatalf("LogSyncSuccess failed: %v", err)
	}

	content, err := os.ReadFile(l.FilePath())
	if err != nil {
		t.Fatalf("failed to read history file: %v", err)
	}

	contentStr := string(content)

	if !strings.Contains(contentStr, "conflicts: 3") {
		t.Error("expected 'conflicts: 3' when conflicts > 0")
	}
}
