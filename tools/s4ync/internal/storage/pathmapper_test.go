package storage_test

import (
	"testing"

	"github.com/arhuman/s4ync/internal/storage"
)

func TestPathMapper_ToRemote(t *testing.T) {
	mapper := storage.NewPathMapper("my-project")

	tests := []struct {
		name      string
		localPath string
		want      string
	}{
		{
			name:      "project.md",
			localPath: "project.md",
			want:      "my-project/project.md",
		},
		{
			name:      "project_history.md",
			localPath: "project_history.md",
			want:      "my-project/project_history.md",
		},
		{
			name:      "task file",
			localPath: "task-001.md",
			want:      "my-project/tasks/task-001.md",
		},
		{
			name:      "task history file",
			localPath: "task-001-history.md",
			want:      "my-project/tasks/task-001-history.md",
		},
		{
			name:      "task with high number",
			localPath: "task-999.md",
			want:      "my-project/tasks/task-999.md",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := mapper.ToRemote(tt.localPath)
			if got != tt.want {
				t.Errorf("ToRemote(%q) = %q, want %q", tt.localPath, got, tt.want)
			}
		})
	}
}

func TestPathMapper_ToLocal(t *testing.T) {
	mapper := storage.NewPathMapper("my-project")

	tests := []struct {
		name       string
		remotePath string
		want       string
	}{
		{
			name:       "project.md",
			remotePath: "my-project/project.md",
			want:       "project.md",
		},
		{
			name:       "project_history.md",
			remotePath: "my-project/project_history.md",
			want:       "project_history.md",
		},
		{
			name:       "task file",
			remotePath: "my-project/tasks/task-001.md",
			want:       "task-001.md",
		},
		{
			name:       "task history file",
			remotePath: "my-project/tasks/task-001-history.md",
			want:       "task-001-history.md",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := mapper.ToLocal(tt.remotePath)
			if got != tt.want {
				t.Errorf("ToLocal(%q) = %q, want %q", tt.remotePath, got, tt.want)
			}
		})
	}
}

func TestIsHistoryFile(t *testing.T) {
	tests := []struct {
		filename string
		want     bool
	}{
		{"task-001-history.md", true},
		{"project_history.md", false}, // Project history is not a -history file
		{"task-001.md", false},
		{"project.md", false},
		{"something-history.md", true},
	}

	for _, tt := range tests {
		t.Run(tt.filename, func(t *testing.T) {
			got := storage.IsHistoryFile(tt.filename)
			if got != tt.want {
				t.Errorf("IsHistoryFile(%q) = %v, want %v", tt.filename, got, tt.want)
			}
		})
	}
}

func TestIsProjectFile(t *testing.T) {
	tests := []struct {
		filename string
		want     bool
	}{
		{"project.md", true},
		{"my-project/project.md", true},
		{"project_history.md", false},
		{"task-001.md", false},
	}

	for _, tt := range tests {
		t.Run(tt.filename, func(t *testing.T) {
			got := storage.IsProjectFile(tt.filename)
			if got != tt.want {
				t.Errorf("IsProjectFile(%q) = %v, want %v", tt.filename, got, tt.want)
			}
		})
	}
}

func TestRoundTrip(t *testing.T) {
	mapper := storage.NewPathMapper("test")

	localFiles := []string{
		"project.md",
		"project_history.md",
		"task-001.md",
		"task-001-history.md",
		"task-999.md",
	}

	for _, local := range localFiles {
		t.Run(local, func(t *testing.T) {
			remote := mapper.ToRemote(local)
			backToLocal := mapper.ToLocal(remote)

			if backToLocal != local {
				t.Errorf("Round trip failed: %q -> %q -> %q", local, remote, backToLocal)
			}
		})
	}
}
