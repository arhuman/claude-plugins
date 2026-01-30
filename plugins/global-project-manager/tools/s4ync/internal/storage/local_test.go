package storage_test

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/arhuman/s4ync/internal/storage"
)

func TestLocalStorage_List(t *testing.T) {
	// Create temp directory
	tmpDir := t.TempDir()

	// Create test files
	testFiles := []string{
		"project.md",
		"project_history.md",
		"task-001.md",
		"task-001-history.md",
	}

	for _, f := range testFiles {
		path := filepath.Join(tmpDir, f)
		if err := os.WriteFile(path, []byte("test content"), 0644); err != nil {
			t.Fatalf("failed to create test file: %v", err)
		}
	}

	// Create a non-md file that should be ignored
	if err := os.WriteFile(filepath.Join(tmpDir, "ignored.txt"), []byte("ignored"), 0644); err != nil {
		t.Fatalf("failed to create ignored file: %v", err)
	}

	s := storage.NewLocalStorage(tmpDir)
	files, err := s.List("")
	if err != nil {
		t.Fatalf("List failed: %v", err)
	}

	if len(files) != len(testFiles) {
		t.Errorf("expected %d files, got %d", len(testFiles), len(files))
	}

	// Check that all expected files are present
	fileMap := make(map[string]bool)
	for _, f := range files {
		fileMap[f.Path] = true
	}

	for _, expected := range testFiles {
		if !fileMap[expected] {
			t.Errorf("expected file %q not found", expected)
		}
	}

	// Verify ignored.txt is not included
	if fileMap["ignored.txt"] {
		t.Error("non-md file should not be listed")
	}
}

func TestLocalStorage_ReadWrite(t *testing.T) {
	tmpDir := t.TempDir()
	s := storage.NewLocalStorage(tmpDir)

	content := []byte("test content for read/write")
	path := "test-file.md"

	// Write
	if err := s.Write(path, content); err != nil {
		t.Fatalf("Write failed: %v", err)
	}

	// Read
	data, err := s.Read(path)
	if err != nil {
		t.Fatalf("Read failed: %v", err)
	}

	if string(data) != string(content) {
		t.Errorf("content mismatch: got %q, want %q", string(data), string(content))
	}
}

func TestLocalStorage_AtomicWrite(t *testing.T) {
	tmpDir := t.TempDir()
	s := storage.NewLocalStorage(tmpDir)

	path := "atomic-test.md"
	content := []byte("final content")

	// Write file
	if err := s.Write(path, content); err != nil {
		t.Fatalf("Write failed: %v", err)
	}

	// Verify no temp file remains
	tmpPath := filepath.Join(tmpDir, path+".tmp")
	if _, err := os.Stat(tmpPath); !os.IsNotExist(err) {
		t.Error("temp file should be removed after write")
	}

	// Verify final file exists with correct content
	data, err := s.Read(path)
	if err != nil {
		t.Fatalf("Read failed: %v", err)
	}
	if string(data) != string(content) {
		t.Errorf("content mismatch")
	}
}

func TestLocalStorage_GetModTime(t *testing.T) {
	tmpDir := t.TempDir()
	s := storage.NewLocalStorage(tmpDir)

	path := "modtime-test.md"

	beforeWrite := time.Now().Add(-time.Second)

	if err := s.Write(path, []byte("content")); err != nil {
		t.Fatalf("Write failed: %v", err)
	}

	afterWrite := time.Now().Add(time.Second)

	modTime, err := s.GetModTime(path)
	if err != nil {
		t.Fatalf("GetModTime failed: %v", err)
	}

	if modTime.Before(beforeWrite) || modTime.After(afterWrite) {
		t.Errorf("modTime %v not in expected range [%v, %v]", modTime, beforeWrite, afterWrite)
	}
}

func TestLocalStorage_Delete(t *testing.T) {
	tmpDir := t.TempDir()
	s := storage.NewLocalStorage(tmpDir)

	path := "delete-test.md"

	// Create file
	if err := s.Write(path, []byte("to be deleted")); err != nil {
		t.Fatalf("Write failed: %v", err)
	}

	// Verify it exists
	exists, err := s.Exists(path)
	if err != nil {
		t.Fatalf("Exists failed: %v", err)
	}
	if !exists {
		t.Error("file should exist before delete")
	}

	// Delete
	if err := s.Delete(path); err != nil {
		t.Fatalf("Delete failed: %v", err)
	}

	// Verify it's gone
	exists, err = s.Exists(path)
	if err != nil {
		t.Fatalf("Exists failed: %v", err)
	}
	if exists {
		t.Error("file should not exist after delete")
	}
}

func TestLocalStorage_Exists(t *testing.T) {
	tmpDir := t.TempDir()
	s := storage.NewLocalStorage(tmpDir)

	// Non-existent file
	exists, err := s.Exists("nonexistent.md")
	if err != nil {
		t.Fatalf("Exists failed: %v", err)
	}
	if exists {
		t.Error("nonexistent file should not exist")
	}

	// Create file
	if err := s.Write("exists.md", []byte("content")); err != nil {
		t.Fatalf("Write failed: %v", err)
	}

	// Now it should exist
	exists, err = s.Exists("exists.md")
	if err != nil {
		t.Fatalf("Exists failed: %v", err)
	}
	if !exists {
		t.Error("file should exist after write")
	}
}

func TestLocalStorage_ReadNonExistent(t *testing.T) {
	tmpDir := t.TempDir()
	s := storage.NewLocalStorage(tmpDir)

	_, err := s.Read("nonexistent.md")
	if err == nil {
		t.Error("expected error reading non-existent file")
	}
	if !os.IsNotExist(err) {
		t.Errorf("expected os.IsNotExist error, got: %v", err)
	}
}
