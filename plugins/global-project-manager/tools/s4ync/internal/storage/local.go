package storage

import (
	"io/fs"
	"os"
	"path/filepath"
	"time"
)

// LocalStorage implements Storage for the local filesystem.
type LocalStorage struct {
	basePath string
}

// NewLocalStorage creates a new LocalStorage rooted at basePath.
func NewLocalStorage(basePath string) *LocalStorage {
	return &LocalStorage{basePath: basePath}
}

// BasePath returns the base path for this storage.
func (s *LocalStorage) BasePath() string {
	return s.basePath
}

// List returns all files under the given prefix.
func (s *LocalStorage) List(prefix string) ([]FileInfo, error) {
	var files []FileInfo

	walkPath := s.basePath
	if prefix != "" {
		walkPath = filepath.Join(s.basePath, prefix)
	}

	err := filepath.WalkDir(walkPath, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			// Skip directories that don't exist
			if os.IsNotExist(err) {
				return nil
			}
			return err
		}

		if d.IsDir() {
			return nil
		}

		// Only include .md files
		if filepath.Ext(path) != ".md" {
			return nil
		}

		info, err := d.Info()
		if err != nil {
			return err
		}

		relPath, _ := filepath.Rel(s.basePath, path)
		files = append(files, FileInfo{
			Path:    relPath,
			ModTime: info.ModTime(),
			Size:    info.Size(),
		})

		return nil
	})

	return files, err
}

// Read returns the contents of a file.
func (s *LocalStorage) Read(path string) ([]byte, error) {
	fullPath := filepath.Join(s.basePath, path)
	return os.ReadFile(fullPath)
}

// Write writes data to a file using atomic write (temp file + rename).
func (s *LocalStorage) Write(path string, data []byte) error {
	fullPath := filepath.Join(s.basePath, path)

	// Ensure parent directory exists
	if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
		return err
	}

	// Atomic write: write to temp file, then rename
	tmpPath := fullPath + ".tmp"
	if err := os.WriteFile(tmpPath, data, 0644); err != nil {
		return err
	}

	return os.Rename(tmpPath, fullPath)
}

// GetModTime returns the modification time of a file.
func (s *LocalStorage) GetModTime(path string) (time.Time, error) {
	fullPath := filepath.Join(s.basePath, path)
	info, err := os.Stat(fullPath)
	if err != nil {
		return time.Time{}, err
	}
	return info.ModTime(), nil
}

// Delete removes a file.
func (s *LocalStorage) Delete(path string) error {
	fullPath := filepath.Join(s.basePath, path)
	return os.Remove(fullPath)
}

// Exists checks if a file exists.
func (s *LocalStorage) Exists(path string) (bool, error) {
	fullPath := filepath.Join(s.basePath, path)
	_, err := os.Stat(fullPath)
	if err == nil {
		return true, nil
	}
	if os.IsNotExist(err) {
		return false, nil
	}
	return false, err
}

// FullPath returns the full filesystem path for a relative path.
func (s *LocalStorage) FullPath(path string) string {
	return filepath.Join(s.basePath, path)
}
