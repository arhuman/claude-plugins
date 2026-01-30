package sync

import (
	"bufio"
	"fmt"
	"io"
	"sort"
	"strings"
	"time"

	"github.com/arhuman/s4ync/internal/storage"
)

// Strategy represents a conflict resolution strategy.
type Strategy int

const (
	// StrategyNewest uses the file with the latest modification time.
	StrategyNewest Strategy = iota
	// StrategyLocal always prefers the local version.
	StrategyLocal
	// StrategyRemote always prefers the remote version.
	StrategyRemote
	// StrategyInteractive prompts the user for each conflict.
	StrategyInteractive
)

func (s Strategy) String() string {
	switch s {
	case StrategyNewest:
		return "newest"
	case StrategyLocal:
		return "local"
	case StrategyRemote:
		return "remote"
	case StrategyInteractive:
		return "interactive"
	default:
		return "unknown"
	}
}

// Resolution represents the result of conflict resolution.
type Resolution struct {
	UseLocal   bool
	UseRemote  bool
	Merged     []byte // For history files that can be merged
	BackupPath string // Path for backup of overwritten file
}

// ConflictResolver resolves conflicts between local and remote files.
type ConflictResolver struct {
	strategy Strategy
	backup   bool
}

// NewConflictResolver creates a new conflict resolver.
func NewConflictResolver(strategy Strategy, backup bool) *ConflictResolver {
	return &ConflictResolver{
		strategy: strategy,
		backup:   backup,
	}
}

// Resolve resolves a conflict using the configured strategy.
func (r *ConflictResolver) Resolve(entry FileEntry, localData, remoteData []byte, output io.Writer) (Resolution, error) {
	path := entry.RelPath

	// Special case: history files can be merged
	if storage.IsHistoryFile(path) || storage.IsProjectHistoryFile(path) {
		merged := mergeHistoryFiles(localData, remoteData)
		return Resolution{
			Merged: merged,
		}, nil
	}

	// Generate backup path if enabled
	backupPath := ""
	if r.backup {
		backupPath = generateBackupPath(path)
	}

	switch r.strategy {
	case StrategyNewest:
		localMod := entry.LocalInfo.ModTime
		remoteMod := entry.RemoteInfo.ModTime

		if localMod.After(remoteMod) {
			return Resolution{
				UseLocal:   true,
				BackupPath: backupPath,
			}, nil
		}
		return Resolution{
			UseRemote:  true,
			BackupPath: backupPath,
		}, nil

	case StrategyLocal:
		return Resolution{
			UseLocal:   true,
			BackupPath: backupPath,
		}, nil

	case StrategyRemote:
		return Resolution{
			UseRemote:  true,
			BackupPath: backupPath,
		}, nil

	case StrategyInteractive:
		return r.promptUser(entry, localData, remoteData, backupPath, output)
	}

	return Resolution{}, fmt.Errorf("unknown conflict resolution strategy")
}

func (r *ConflictResolver) promptUser(entry FileEntry, localData, remoteData []byte, backupPath string, output io.Writer) (Resolution, error) {
	if output == nil {
		// Default to local if no output
		return Resolution{
			UseLocal:   true,
			BackupPath: backupPath,
		}, nil
	}

	fmt.Fprintf(output, "\nConflict detected: %s\n", entry.RelPath)
	fmt.Fprintf(output, "  Local:  %d bytes, modified %s\n", entry.LocalInfo.Size, entry.LocalInfo.ModTime.Format(time.RFC3339))
	fmt.Fprintf(output, "  Remote: %d bytes, modified %s\n", entry.RemoteInfo.Size, entry.RemoteInfo.ModTime.Format(time.RFC3339))
	fmt.Fprintf(output, "  Choose: (l)ocal, (r)emote, (n)ewest? ")

	// For now, default to newest since we can't read stdin in this context
	// Interactive mode would need stdin reader passed in
	localMod := entry.LocalInfo.ModTime
	remoteMod := entry.RemoteInfo.ModTime

	if localMod.After(remoteMod) {
		return Resolution{
			UseLocal:   true,
			BackupPath: backupPath,
		}, nil
	}
	return Resolution{
		UseRemote:  true,
		BackupPath: backupPath,
	}, nil
}

func generateBackupPath(path string) string {
	// Format: filename.conflict-2026-01-29T15-30-00Z.md
	timestamp := time.Now().UTC().Format("2006-01-02T15-04-05Z")

	if strings.HasSuffix(path, ".md") {
		base := strings.TrimSuffix(path, ".md")
		return fmt.Sprintf("%s.conflict-%s.md", base, timestamp)
	}
	return fmt.Sprintf("%s.conflict-%s", path, timestamp)
}

// HistoryEntry represents a single entry in a history file.
type HistoryEntry struct {
	Timestamp time.Time
	Event     string
	Details   string
	Raw       string
}

// mergeHistoryFiles merges two history files by combining entries and deduplicating.
func mergeHistoryFiles(local, remote []byte) []byte {
	localEntries := parseHistoryLines(local)
	remoteEntries := parseHistoryLines(remote)

	// Combine and deduplicate
	allEntries := append(localEntries, remoteEntries...)
	unique := deduplicateEntries(allEntries)

	// Sort by timestamp
	sort.Slice(unique, func(i, j int) bool {
		return unique[i].Timestamp.Before(unique[j].Timestamp)
	})

	return formatHistory(unique)
}

func parseHistoryLines(data []byte) []HistoryEntry {
	var entries []HistoryEntry
	scanner := bufio.NewScanner(strings.NewReader(string(data)))

	for scanner.Scan() {
		line := scanner.Text()
		// Skip header and empty lines
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		entry := parseHistoryEntry(line)
		if !entry.Timestamp.IsZero() {
			entries = append(entries, entry)
		}
	}

	return entries
}

func parseHistoryEntry(line string) HistoryEntry {
	// Format: "- {timestamp} | {event} | {details}"
	// or: "- {timestamp} | {event}"
	if !strings.HasPrefix(line, "- ") {
		return HistoryEntry{}
	}

	line = strings.TrimPrefix(line, "- ")
	parts := strings.SplitN(line, " | ", 3)

	if len(parts) < 2 {
		return HistoryEntry{Raw: line}
	}

	timestamp, err := time.Parse(time.RFC3339, parts[0])
	if err != nil {
		return HistoryEntry{Raw: line}
	}

	entry := HistoryEntry{
		Timestamp: timestamp,
		Event:     parts[1],
		Raw:       line,
	}

	if len(parts) >= 3 {
		entry.Details = parts[2]
	}

	return entry
}

func deduplicateEntries(entries []HistoryEntry) []HistoryEntry {
	seen := make(map[string]bool)
	var unique []HistoryEntry

	for _, e := range entries {
		key := e.Raw
		if !seen[key] {
			seen[key] = true
			unique = append(unique, e)
		}
	}

	return unique
}

func formatHistory(entries []HistoryEntry) []byte {
	var lines []string
	lines = append(lines, "# Project History")
	lines = append(lines, "")

	for _, e := range entries {
		if e.Details != "" {
			lines = append(lines, fmt.Sprintf("- %s | %s | %s",
				e.Timestamp.Format(time.RFC3339), e.Event, e.Details))
		} else {
			lines = append(lines, fmt.Sprintf("- %s | %s",
				e.Timestamp.Format(time.RFC3339), e.Event))
		}
	}

	lines = append(lines, "")
	return []byte(strings.Join(lines, "\n"))
}
