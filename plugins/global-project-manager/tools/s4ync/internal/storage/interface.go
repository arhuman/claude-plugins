// Package storage provides abstractions for local and S3 file storage.
package storage

import "time"

// FileInfo represents metadata about a file.
type FileInfo struct {
	Path        string
	ModTime     time.Time
	Size        int64
	IsDirectory bool
}

// Storage defines the interface for file storage operations.
type Storage interface {
	// List returns all files under the given prefix.
	List(prefix string) ([]FileInfo, error)

	// Read returns the contents of a file.
	Read(path string) ([]byte, error)

	// Write writes data to a file. Implementations should use atomic writes.
	Write(path string, data []byte) error

	// GetModTime returns the modification time of a file.
	GetModTime(path string) (time.Time, error)

	// Delete removes a file.
	Delete(path string) error

	// Exists checks if a file exists.
	Exists(path string) (bool, error)
}

// PathMapper handles path transformations between local and remote storage.
type PathMapper interface {
	// ToRemote converts a local path to a remote path.
	ToRemote(localPath string) string

	// ToLocal converts a remote path to a local path.
	ToLocal(remotePath string) string
}
