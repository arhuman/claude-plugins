// Package logger provides logging utilities for s4ync, including
// project_history.md updates.
package logger

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const historyFilename = "project_history.md"

// HistoryLogger appends sync events to project_history.md.
type HistoryLogger struct {
	filePath string
}

// NewHistoryLogger creates a new history logger for the given project directory.
func NewHistoryLogger(projectPath string) *HistoryLogger {
	return &HistoryLogger{
		filePath: filepath.Join(projectPath, historyFilename),
	}
}

// LogSyncSuccess logs a successful sync operation.
func (l *HistoryLogger) LogSyncSuccess(uploaded, downloaded, conflicts int) error {
	details := fmt.Sprintf("uploaded: %d, downloaded: %d", uploaded, downloaded)
	if conflicts > 0 {
		details += fmt.Sprintf(", conflicts: %d", conflicts)
	}
	return l.AppendEntry("synced", details)
}

// LogSyncFailure logs a failed sync operation.
func (l *HistoryLogger) LogSyncFailure(reason string) error {
	return l.AppendEntry("sync_failed", reason)
}

// LogPartialSync logs a partial sync (some files succeeded, some failed).
func (l *HistoryLogger) LogPartialSync(uploaded, downloaded, errors int) error {
	details := fmt.Sprintf("uploaded: %d, downloaded: %d, errors: %d", uploaded, downloaded, errors)
	return l.AppendEntry("sync_partial", details)
}

// AppendEntry appends a new entry to the history file.
// Entry format: "- {ISO8601} | {event} | {details}"
func (l *HistoryLogger) AppendEntry(event, details string) error {
	timestamp := time.Now().UTC().Format(time.RFC3339)

	var entry string
	if details != "" {
		entry = fmt.Sprintf("- %s | %s | %s\n", timestamp, event, details)
	} else {
		entry = fmt.Sprintf("- %s | %s\n", timestamp, event)
	}

	// Read existing content or create new file
	content, err := os.ReadFile(l.filePath)
	if os.IsNotExist(err) {
		// Create new history file
		content = []byte("# Project History\n\n")
	} else if err != nil {
		return fmt.Errorf("read history file: %w", err)
	}

	// Append entry
	newContent := string(content)
	if !strings.HasSuffix(newContent, "\n") {
		newContent += "\n"
	}
	newContent += entry

	// Write atomically
	tmpPath := l.filePath + ".tmp"
	if err := os.WriteFile(tmpPath, []byte(newContent), 0644); err != nil {
		return fmt.Errorf("write temp history file: %w", err)
	}

	if err := os.Rename(tmpPath, l.filePath); err != nil {
		return fmt.Errorf("rename history file: %w", err)
	}

	return nil
}

// FilePath returns the path to the history file.
func (l *HistoryLogger) FilePath() string {
	return l.filePath
}
