package cmd

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/spf13/cobra"

	"github.com/arhuman/s4ync/internal/config"
	"github.com/arhuman/s4ync/internal/logger"
	"github.com/arhuman/s4ync/internal/parser"
	"github.com/arhuman/s4ync/internal/storage"
	"github.com/arhuman/s4ync/internal/sync"
)

var (
	projectPath  string
	dryRun       bool
	forceUp      bool
	forceDown    bool
	preferLocal  bool
	preferRemote bool
	interactive  bool
	verbose      bool
)

var syncCmd = &cobra.Command{
	Use:   "sync",
	Short: "Synchronize local and remote project data",
	Long: `Synchronize the local .claude/global-project directory with MinIO S3.

The sync command compares local and remote files using the last_sync timestamp
from project.md and determines which files need to be uploaded or downloaded.

By default, conflicts (files modified on both sides since last sync) are
resolved using the newest version. Use flags to specify alternate strategies.`,
	RunE: runSync,
}

func init() {
	syncCmd.Flags().StringVarP(&projectPath, "path", "p", "", "Path to project directory (auto-detect if not specified)")
	syncCmd.Flags().BoolVarP(&dryRun, "dry-run", "n", false, "Show what would be synced without making changes")
	syncCmd.Flags().BoolVar(&forceUp, "force-up", false, "Force upload all files (ignore remote changes)")
	syncCmd.Flags().BoolVar(&forceDown, "force-down", false, "Force download all files (ignore local changes)")
	syncCmd.Flags().BoolVar(&preferLocal, "prefer-local", false, "Always use local version on conflict")
	syncCmd.Flags().BoolVar(&preferRemote, "prefer-remote", false, "Always use remote version on conflict")
	syncCmd.Flags().BoolVarP(&interactive, "interactive", "i", false, "Prompt for each conflict")
	syncCmd.Flags().BoolVarP(&verbose, "verbose", "v", false, "Verbose output with detailed logging")

	rootCmd.AddCommand(syncCmd)
}

func runSync(cmd *cobra.Command, args []string) error {
	// Load configuration
	cfg, err := config.LoadFromEnv()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Configuration error: %v\n", err)
		os.Exit(2)
	}

	// Resolve project path
	if projectPath != "" {
		cfg.ProjectPath = projectPath
	}
	projPath, err := findProjectPath(cfg.ProjectPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(3)
	}
	cfg.ProjectPath = projPath

	// Read project.md to get shortname and last_sync
	projectMdPath := filepath.Join(cfg.ProjectPath, "project.md")
	projectData, err := os.ReadFile(projectMdPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Critical error: cannot read project.md: %v\n", err)
		os.Exit(3)
	}

	fm, err := parser.Parse(projectData)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Critical error: cannot parse project.md: %v\n", err)
		os.Exit(3)
	}

	shortname := fm.GetString("shortname")
	if shortname == "" {
		fmt.Fprintf(os.Stderr, "Critical error: shortname not found in project.md\n")
		os.Exit(3)
	}

	lastSync := fm.GetTime("last_sync")

	// Print sync info
	fmt.Printf("Syncing project: %s (shortname: %s)\n", fm.GetString("name"), shortname)
	if lastSync != nil {
		fmt.Printf("Last sync: %s\n", lastSync.Format(time.RFC3339))
	} else {
		fmt.Println("Last sync: never")
	}
	fmt.Printf("S3 bucket: %s\n", cfg.BucketName)
	fmt.Println()

	// Create storages
	local := storage.NewLocalStorage(cfg.ProjectPath)
	remote, err := storage.NewS3Storage(cfg, shortname)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error connecting to S3: %v\n", err)
		os.Exit(1)
	}

	// Ensure bucket exists
	if err := remote.EnsureBucket(context.Background()); err != nil {
		fmt.Fprintf(os.Stderr, "Error creating bucket: %v\n", err)
		os.Exit(1)
	}

	// Create path mapper
	pathMapper := storage.NewPathMapper(shortname)

	// Build inventory
	fmt.Println("Building inventory...")
	inventory, err := sync.BuildInventory(local, remote, pathMapper, lastSync)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error building inventory: %v\n", err)
		os.Exit(1)
	}

	localOnly, remoteOnly, both := inventory.Stats()
	fmt.Printf("  Local files:  %d\n", localOnly+both)
	fmt.Printf("  Remote files: %d\n", remoteOnly+both)
	fmt.Println()

	// Analyze changes
	fmt.Println("Analyzing changes...")
	decisions := sync.DecideAll(inventory)
	counts := sync.CountByAction(decisions)

	fmt.Printf("  Upload:    %d files\n", counts[sync.ActionUpload])
	fmt.Printf("  Download:  %d files\n", counts[sync.ActionDownload])
	fmt.Printf("  Conflicts: %d files\n", counts[sync.ActionConflict])
	fmt.Printf("  Skip:      %d files\n", counts[sync.ActionSkip])
	fmt.Println()

	// Check for nothing to do
	if counts[sync.ActionUpload] == 0 && counts[sync.ActionDownload] == 0 && counts[sync.ActionConflict] == 0 {
		fmt.Println("Everything is up to date. Nothing to sync.")
		return nil
	}

	// Create sync engine
	engine := sync.NewEngine(local, remote, pathMapper)

	// Set conflict resolution strategy
	strategy := sync.StrategyNewest
	if preferLocal {
		strategy = sync.StrategyLocal
	} else if preferRemote {
		strategy = sync.StrategyRemote
	} else if interactive {
		strategy = sync.StrategyInteractive
	}
	engine.SetConflictResolver(sync.NewConflictResolver(strategy, true))

	// Create sync options
	opts := &sync.Options{
		DryRun:       dryRun,
		ForceUp:      forceUp,
		ForceDown:    forceDown,
		PreferLocal:  preferLocal,
		PreferRemote: preferRemote,
		Interactive:  interactive,
		Verbose:      verbose,
		Output:       os.Stdout,
	}

	// Execute sync
	if dryRun {
		fmt.Println("Dry run mode - no changes will be made:")
	} else {
		fmt.Println("Syncing...")
	}

	result, err := engine.Sync(inventory, opts)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Sync error: %v\n", err)
		os.Exit(1)
	}

	// Print results if not verbose (verbose already printed during sync)
	if !verbose && !dryRun {
		for _, path := range result.Uploaded {
			fmt.Printf("  Uploaded: %s\n", path)
		}
		for _, path := range result.Downloaded {
			fmt.Printf("  Downloaded: %s\n", path)
		}
		for _, path := range result.Conflicts {
			fmt.Printf("  Resolved: %s\n", path)
		}
	}

	// Update last_sync if not dry run and no errors
	if !dryRun && !result.HasErrors() {
		fmt.Println()
		fmt.Println("Updating last_sync timestamp...")

		newTime := time.Now().UTC()
		fm.Set("last_sync", newTime)

		updatedData, err := fm.Marshal()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Warning: failed to update last_sync: %v\n", err)
		} else {
			if err := local.Write("project.md", updatedData); err != nil {
				fmt.Fprintf(os.Stderr, "Warning: failed to write project.md: %v\n", err)
			}

			// Also upload updated project.md to remote
			if err := remote.Write("project.md", updatedData); err != nil {
				fmt.Fprintf(os.Stderr, "Warning: failed to sync project.md to remote: %v\n", err)
			}
		}

		// Log to history
		histLogger := logger.NewHistoryLogger(cfg.ProjectPath)
		if err := histLogger.LogSyncSuccess(len(result.Uploaded), len(result.Downloaded), len(result.Conflicts)); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: failed to log sync: %v\n", err)
		}
	}

	// Print final summary
	fmt.Println()
	if dryRun {
		fmt.Println("Dry run completed. No changes were made.")
	} else {
		fmt.Printf("Sync completed successfully!\n")
	}
	fmt.Printf("  %s\n", result.Summary())

	// Handle errors
	if result.HasErrors() {
		fmt.Println()
		fmt.Println("Some files failed to sync:")
		for _, err := range result.Errors {
			fmt.Printf("  - %s\n", err.Error())
		}

		// Log partial sync
		if !dryRun {
			histLogger := logger.NewHistoryLogger(cfg.ProjectPath)
			histLogger.LogPartialSync(len(result.Uploaded), len(result.Downloaded), len(result.Errors))
		}

		os.Exit(1)
	}

	return nil
}

// findProjectPath finds the project directory, searching up from current dir if needed.
func findProjectPath(configPath string) (string, error) {
	// If explicit path, use it
	if configPath != "" && filepath.IsAbs(configPath) {
		if _, err := os.Stat(filepath.Join(configPath, "project.md")); err == nil {
			return configPath, nil
		}
		return "", fmt.Errorf("project.md not found at %s", configPath)
	}

	// Try default path relative to current directory
	if configPath == "" {
		configPath = ".claude/global-project"
	}

	// Try current directory first
	cwd, err := os.Getwd()
	if err != nil {
		return "", err
	}

	// Try relative path from cwd
	tryPath := filepath.Join(cwd, configPath)
	if _, err := os.Stat(filepath.Join(tryPath, "project.md")); err == nil {
		return tryPath, nil
	}

	// Search up the directory tree
	dir := cwd
	for {
		tryPath := filepath.Join(dir, configPath)
		if _, err := os.Stat(filepath.Join(tryPath, "project.md")); err == nil {
			return tryPath, nil
		}

		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}

	return "", fmt.Errorf("could not find project directory with project.md (searched from %s)", cwd)
}
