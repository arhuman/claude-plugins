package storage

import (
	"path/filepath"
	"strings"
)

// DefaultPathMapper maps between local flat structure and S3 with tasks/ subdirectory.
// Local: task-001.md -> S3: tasks/task-001.md
// Local: project.md -> S3: project.md
type DefaultPathMapper struct {
	shortname string
}

// NewPathMapper creates a new path mapper for the given project shortname.
func NewPathMapper(shortname string) *DefaultPathMapper {
	return &DefaultPathMapper{shortname: shortname}
}

// ToRemote converts a local path to a remote path.
// Task files go into tasks/ subdirectory, other files stay at root.
func (m *DefaultPathMapper) ToRemote(localPath string) string {
	base := filepath.Base(localPath)

	// Task files and task history files go into tasks/ subdirectory
	if isTaskFile(base) {
		return m.shortname + "/tasks/" + base
	}

	// Project files stay at root
	return m.shortname + "/" + base
}

// ToLocal converts a remote path to a local path.
func (m *DefaultPathMapper) ToLocal(remotePath string) string {
	// Remove shortname prefix
	path := strings.TrimPrefix(remotePath, m.shortname+"/")

	// Remove tasks/ subdirectory if present
	path = strings.TrimPrefix(path, "tasks/")

	return path
}

// isTaskFile checks if a filename is a task file (task-XXX.md or task-XXX-history.md).
func isTaskFile(filename string) bool {
	return strings.HasPrefix(filename, "task-") && strings.HasSuffix(filename, ".md")
}

// IsHistoryFile checks if a filename is a history file (*-history.md).
func IsHistoryFile(filename string) bool {
	return strings.HasSuffix(filename, "-history.md")
}

// IsProjectFile checks if a filename is the project.md file.
func IsProjectFile(filename string) bool {
	return filename == "project.md" || strings.HasSuffix(filename, "/project.md")
}

// IsProjectHistoryFile checks if a filename is the project_history.md file.
func IsProjectHistoryFile(filename string) bool {
	return filename == "project_history.md" || strings.HasSuffix(filename, "/project_history.md")
}
