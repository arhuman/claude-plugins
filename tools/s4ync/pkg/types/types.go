// Package types defines shared types for s4ync.
package types

import "time"

// Project represents project.md frontmatter.
type Project struct {
	Shortname string     `yaml:"shortname"`
	Name      string     `yaml:"name"`
	CreatedAt time.Time  `yaml:"created_at"`
	LastSync  *time.Time `yaml:"last_sync"`
	GitRepo   *string    `yaml:"git_repo"`
	JJRepo    bool       `yaml:"jj_repo"`
}

// Task represents task-XXX.md frontmatter.
type Task struct {
	ID          string     `yaml:"id"`
	Title       string     `yaml:"title"`
	Status      string     `yaml:"status"`
	Priority    string     `yaml:"priority"`
	CreatedAt   time.Time  `yaml:"created_at"`
	StartedAt   *time.Time `yaml:"started_at"`
	CompletedAt *time.Time `yaml:"completed_at"`
}

// Status constants for tasks.
const (
	StatusBacklog    = "backlog"
	StatusTodo       = "todo"
	StatusInProgress = "in_progress"
	StatusDone       = "done"
	StatusCancelled  = "cancelled"
)

// Priority constants for tasks.
const (
	PriorityLow      = "low"
	PriorityMedium   = "medium"
	PriorityHigh     = "high"
	PriorityCritical = "critical"
)

// ExitCode represents program exit codes.
type ExitCode int

const (
	// ExitSuccess indicates all operations completed successfully.
	ExitSuccess ExitCode = 0
	// ExitPartialFailure indicates some files failed but sync continued.
	ExitPartialFailure ExitCode = 1
	// ExitConfigError indicates invalid configuration or environment.
	ExitConfigError ExitCode = 2
	// ExitCriticalError indicates cannot read project.md or critical failure.
	ExitCriticalError ExitCode = 3
)
