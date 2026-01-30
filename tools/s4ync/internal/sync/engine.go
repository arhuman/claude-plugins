package sync

import (
	"fmt"
	"io"
	"time"

	"github.com/arhuman/s4ync/internal/storage"
)

// Options contains configuration for sync operations.
type Options struct {
	DryRun       bool
	ForceUp      bool
	ForceDown    bool
	PreferLocal  bool
	PreferRemote bool
	Interactive  bool
	Verbose      bool
	Output       io.Writer
}

// Result contains the outcome of a sync operation.
type Result struct {
	Uploaded   []string
	Downloaded []string
	Skipped    []string
	Conflicts  []string
	Errors     []SyncError
	StartTime  time.Time
	EndTime    time.Time
}

// SyncError represents an error that occurred during sync.
type SyncError struct {
	Path    string
	Op      string
	Err     error
	Skipped bool // If true, sync continued despite error
}

func (e SyncError) Error() string {
	return fmt.Sprintf("%s %s: %v", e.Op, e.Path, e.Err)
}

// HasErrors returns true if any errors occurred.
func (r *Result) HasErrors() bool {
	return len(r.Errors) > 0
}

// Summary returns a human-readable summary of the result.
func (r *Result) Summary() string {
	return fmt.Sprintf("Uploaded: %d, Downloaded: %d, Skipped: %d, Conflicts: %d, Errors: %d",
		len(r.Uploaded), len(r.Downloaded), len(r.Skipped), len(r.Conflicts), len(r.Errors))
}

// Engine performs sync operations between local and remote storage.
type Engine struct {
	local      storage.Storage
	remote     storage.Storage
	pathMapper *storage.DefaultPathMapper
	resolver   *ConflictResolver
}

// NewEngine creates a new sync engine.
func NewEngine(local, remote storage.Storage, pathMapper *storage.DefaultPathMapper) *Engine {
	return &Engine{
		local:      local,
		remote:     remote,
		pathMapper: pathMapper,
		resolver:   NewConflictResolver(StrategyNewest, true),
	}
}

// SetConflictResolver sets the conflict resolution strategy.
func (e *Engine) SetConflictResolver(resolver *ConflictResolver) {
	e.resolver = resolver
}

// Sync performs synchronization based on the inventory and options.
func (e *Engine) Sync(inventory *Inventory, opts *Options) (*Result, error) {
	result := &Result{
		StartTime: time.Now(),
	}

	// Determine actions for each file
	decisions := DecideAll(inventory)

	// Apply force flags if set
	if opts.ForceUp {
		decisions = e.forceUpload(inventory)
	} else if opts.ForceDown {
		decisions = e.forceDownload(inventory)
	}

	// Execute decisions
	for _, decision := range decisions {
		if err := e.executeDecision(decision, opts, result); err != nil {
			// Non-blocking: log error and continue
			result.Errors = append(result.Errors, SyncError{
				Path:    decision.Entry.RelPath,
				Op:      decision.Action.String(),
				Err:     err,
				Skipped: true,
			})
		}
	}

	result.EndTime = time.Now()
	return result, nil
}

func (e *Engine) executeDecision(decision Decision, opts *Options, result *Result) error {
	path := decision.Entry.RelPath

	switch decision.Action {
	case ActionSkip:
		result.Skipped = append(result.Skipped, path)
		if opts.Verbose && opts.Output != nil {
			fmt.Fprintf(opts.Output, "  Skip: %s (%s)\n", path, decision.Reason)
		}
		return nil

	case ActionUpload:
		if opts.DryRun {
			if opts.Output != nil {
				fmt.Fprintf(opts.Output, "[DRY RUN] Would upload: %s\n", path)
			}
			result.Uploaded = append(result.Uploaded, path)
			return nil
		}
		if err := e.upload(path); err != nil {
			return err
		}
		result.Uploaded = append(result.Uploaded, path)
		if opts.Verbose && opts.Output != nil {
			fmt.Fprintf(opts.Output, "  Uploaded: %s\n", path)
		}
		return nil

	case ActionDownload:
		if opts.DryRun {
			if opts.Output != nil {
				fmt.Fprintf(opts.Output, "[DRY RUN] Would download: %s\n", path)
			}
			result.Downloaded = append(result.Downloaded, path)
			return nil
		}
		if err := e.download(path); err != nil {
			return err
		}
		result.Downloaded = append(result.Downloaded, path)
		if opts.Verbose && opts.Output != nil {
			fmt.Fprintf(opts.Output, "  Downloaded: %s\n", path)
		}
		return nil

	case ActionConflict:
		return e.handleConflict(decision, opts, result)
	}

	return nil
}

func (e *Engine) upload(path string) error {
	data, err := e.local.Read(path)
	if err != nil {
		return fmt.Errorf("read local file: %w", err)
	}

	// Map local path to remote path (adds tasks/ for task files)
	remotePath := localToRemotePath(path)

	if err := e.remote.Write(remotePath, data); err != nil {
		return fmt.Errorf("write to remote: %w", err)
	}

	return nil
}

func (e *Engine) download(path string) error {
	// Map local path to remote path (adds tasks/ for task files)
	remotePath := localToRemotePath(path)

	data, err := e.remote.Read(remotePath)
	if err != nil {
		return fmt.Errorf("read remote file: %w", err)
	}

	if err := e.local.Write(path, data); err != nil {
		return fmt.Errorf("write to local: %w", err)
	}

	return nil
}

func (e *Engine) handleConflict(decision Decision, opts *Options, result *Result) error {
	path := decision.Entry.RelPath

	// Determine strategy from options
	strategy := e.resolver.strategy
	if opts.PreferLocal {
		strategy = StrategyLocal
	} else if opts.PreferRemote {
		strategy = StrategyRemote
	} else if opts.Interactive {
		strategy = StrategyInteractive
	}

	resolver := NewConflictResolver(strategy, e.resolver.backup)

	// Read both versions
	localData, err := e.local.Read(path)
	if err != nil {
		return fmt.Errorf("read local for conflict: %w", err)
	}

	remotePath := localToRemotePath(path)
	remoteData, err := e.remote.Read(remotePath)
	if err != nil {
		return fmt.Errorf("read remote for conflict: %w", err)
	}

	// Resolve conflict
	resolution, err := resolver.Resolve(decision.Entry, localData, remoteData, opts.Output)
	if err != nil {
		return fmt.Errorf("resolve conflict: %w", err)
	}

	if opts.DryRun {
		if opts.Output != nil {
			fmt.Fprintf(opts.Output, "[DRY RUN] Would resolve conflict: %s (use %s)\n", path, resolutionDesc(resolution))
		}
		result.Conflicts = append(result.Conflicts, path)
		return nil
	}

	// Create backup if configured
	if e.resolver.backup && resolution.BackupPath != "" {
		if resolution.UseLocal {
			// Backup remote version
			if err := e.local.Write(resolution.BackupPath, remoteData); err != nil {
				return fmt.Errorf("create backup: %w", err)
			}
		} else if resolution.UseRemote {
			// Backup local version
			if err := e.local.Write(resolution.BackupPath, localData); err != nil {
				return fmt.Errorf("create backup: %w", err)
			}
		}
	}

	// Apply resolution
	if resolution.UseLocal {
		if err := e.remote.Write(remotePath, localData); err != nil {
			return fmt.Errorf("upload local version: %w", err)
		}
		result.Uploaded = append(result.Uploaded, path)
	} else if resolution.UseRemote {
		if err := e.local.Write(path, remoteData); err != nil {
			return fmt.Errorf("download remote version: %w", err)
		}
		result.Downloaded = append(result.Downloaded, path)
	} else if resolution.Merged != nil {
		// Write merged version to both
		if err := e.local.Write(path, resolution.Merged); err != nil {
			return fmt.Errorf("write merged local: %w", err)
		}
		if err := e.remote.Write(remotePath, resolution.Merged); err != nil {
			return fmt.Errorf("write merged remote: %w", err)
		}
		result.Uploaded = append(result.Uploaded, path)
	}

	result.Conflicts = append(result.Conflicts, path)
	if opts.Verbose && opts.Output != nil {
		fmt.Fprintf(opts.Output, "  Resolved conflict: %s (%s)\n", path, resolutionDesc(resolution))
	}

	return nil
}

// localToRemotePath converts a local path to the remote S3 path.
// Task files go into tasks/ subdirectory, project files stay at root.
func localToRemotePath(localPath string) string {
	if storage.IsHistoryFile(localPath) && !storage.IsProjectHistoryFile(localPath) {
		// Task history files go into tasks/
		return "tasks/" + localPath
	}
	if len(localPath) > 5 && localPath[:5] == "task-" {
		// Task files go into tasks/
		return "tasks/" + localPath
	}
	// Project files stay at root
	return localPath
}

func resolutionDesc(r Resolution) string {
	if r.UseLocal {
		return "kept local"
	}
	if r.UseRemote {
		return "kept remote"
	}
	if r.Merged != nil {
		return "merged"
	}
	return "unknown"
}

func (e *Engine) forceUpload(inventory *Inventory) []Decision {
	var decisions []Decision
	for _, entry := range inventory.Files {
		if entry.LocalInfo != nil {
			decisions = append(decisions, Decision{
				Entry:  entry,
				Action: ActionUpload,
				Reason: "force upload",
			})
		}
	}
	return decisions
}

func (e *Engine) forceDownload(inventory *Inventory) []Decision {
	var decisions []Decision
	for _, entry := range inventory.Files {
		if entry.RemoteInfo != nil {
			decisions = append(decisions, Decision{
				Entry:  entry,
				Action: ActionDownload,
				Reason: "force download",
			})
		}
	}
	return decisions
}
