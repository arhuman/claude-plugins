// Package cmd implements the CLI commands for s4ync.
package cmd

import (
	"os"

	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "s4ync",
	Short: "Sync .claude/global-project with MinIO S3",
	Long: `S4YNC (pronounced "sync") is a bidirectional file synchronization tool
that syncs the .claude/global-project directory with a MinIO S3 bucket.

It enables project and task data to be synchronized across machines
while handling conflicts intelligently.`,
	// Run sync by default when no subcommand is specified
	RunE: func(cmd *cobra.Command, args []string) error {
		// Forward to sync command
		return runSync(cmd, args)
	},
}

func init() {
	// Add sync command flags to root for default behavior
	rootCmd.Flags().StringVarP(&projectPath, "path", "p", "", "Path to project directory (auto-detect if not specified)")
	rootCmd.Flags().BoolVarP(&dryRun, "dry-run", "n", false, "Show what would be synced without making changes")
	rootCmd.Flags().BoolVar(&forceUp, "force-up", false, "Force upload all files (ignore remote changes)")
	rootCmd.Flags().BoolVar(&forceDown, "force-down", false, "Force download all files (ignore local changes)")
	rootCmd.Flags().BoolVar(&preferLocal, "prefer-local", false, "Always use local version on conflict")
	rootCmd.Flags().BoolVar(&preferRemote, "prefer-remote", false, "Always use remote version on conflict")
	rootCmd.Flags().BoolVarP(&interactive, "interactive", "i", false, "Prompt for each conflict")
	rootCmd.Flags().BoolVarP(&verbose, "verbose", "v", false, "Verbose output with detailed logging")
}

// Execute runs the root command.
func Execute() error {
	// If no args or unknown command, run sync
	if len(os.Args) == 1 || (len(os.Args) > 1 && os.Args[1][0] == '-') {
		// Direct call with flags
		return syncCmd.Execute()
	}
	return rootCmd.Execute()
}
