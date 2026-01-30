// Package sync implements the synchronization engine for s4ync.
package sync

import (
	"time"

	"github.com/arhuman/s4ync/internal/storage"
)

// FileEntry represents a file that may exist in local and/or remote storage.
type FileEntry struct {
	// RelPath is the relative path in local storage (e.g., "task-001.md").
	RelPath string
	// LocalInfo contains metadata if file exists locally.
	LocalInfo *storage.FileInfo
	// RemoteInfo contains metadata if file exists remotely.
	RemoteInfo *storage.FileInfo
}

// Inventory contains all files from both local and remote storage.
type Inventory struct {
	Files    []FileEntry
	LastSync *time.Time
}

// BuildInventory creates an inventory from local and remote storage.
// The pathMapper is used to correlate local paths with remote paths.
func BuildInventory(local, remote storage.Storage, pathMapper *storage.DefaultPathMapper, lastSync *time.Time) (*Inventory, error) {
	inventory := &Inventory{
		LastSync: lastSync,
	}

	// Map to track files by local path
	fileMap := make(map[string]*FileEntry)

	// List local files
	localFiles, err := local.List("")
	if err != nil {
		return nil, err
	}

	for _, f := range localFiles {
		info := f // Copy to avoid pointer issues
		fileMap[f.Path] = &FileEntry{
			RelPath:   f.Path,
			LocalInfo: &info,
		}
	}

	// List remote files
	remoteFiles, err := remote.List("")
	if err != nil {
		return nil, err
	}

	for _, f := range remoteFiles {
		localPath := pathMapper.ToLocal(f.Path)
		info := f // Copy

		if entry, exists := fileMap[localPath]; exists {
			entry.RemoteInfo = &info
		} else {
			fileMap[localPath] = &FileEntry{
				RelPath:    localPath,
				RemoteInfo: &info,
			}
		}
	}

	// Convert map to slice
	for _, entry := range fileMap {
		inventory.Files = append(inventory.Files, *entry)
	}

	return inventory, nil
}

// LocalOnlyFiles returns files that exist only locally.
func (inv *Inventory) LocalOnlyFiles() []FileEntry {
	var result []FileEntry
	for _, f := range inv.Files {
		if f.LocalInfo != nil && f.RemoteInfo == nil {
			result = append(result, f)
		}
	}
	return result
}

// RemoteOnlyFiles returns files that exist only remotely.
func (inv *Inventory) RemoteOnlyFiles() []FileEntry {
	var result []FileEntry
	for _, f := range inv.Files {
		if f.LocalInfo == nil && f.RemoteInfo != nil {
			result = append(result, f)
		}
	}
	return result
}

// BothSidesFiles returns files that exist on both sides.
func (inv *Inventory) BothSidesFiles() []FileEntry {
	var result []FileEntry
	for _, f := range inv.Files {
		if f.LocalInfo != nil && f.RemoteInfo != nil {
			result = append(result, f)
		}
	}
	return result
}

// Stats returns counts of files in various states.
func (inv *Inventory) Stats() (localOnly, remoteOnly, both int) {
	for _, f := range inv.Files {
		switch {
		case f.LocalInfo != nil && f.RemoteInfo == nil:
			localOnly++
		case f.LocalInfo == nil && f.RemoteInfo != nil:
			remoteOnly++
		case f.LocalInfo != nil && f.RemoteInfo != nil:
			both++
		}
	}
	return
}
