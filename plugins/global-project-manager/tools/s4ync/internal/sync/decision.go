package sync

import (
	"time"
)

// Action represents the sync action to take for a file.
type Action int

const (
	// ActionSkip means no action needed - file unchanged on both sides.
	ActionSkip Action = iota
	// ActionUpload means upload local file to remote.
	ActionUpload
	// ActionDownload means download remote file to local.
	ActionDownload
	// ActionConflict means both sides modified since last sync.
	ActionConflict
)

func (a Action) String() string {
	switch a {
	case ActionSkip:
		return "skip"
	case ActionUpload:
		return "upload"
	case ActionDownload:
		return "download"
	case ActionConflict:
		return "conflict"
	default:
		return "unknown"
	}
}

// Decision represents the sync decision for a file.
type Decision struct {
	Entry  FileEntry
	Action Action
	Reason string
}

// Decide determines what action to take for a file entry.
//
// Decision Matrix:
// | Local Modified | S3 Modified | Decision    |
// |----------------|-------------|-------------|
// | After lastSync | After lastSync | CONFLICT |
// | After lastSync | Before/Equal   | UPLOAD   |
// | Before/Equal   | After lastSync | DOWNLOAD |
// | Before/Equal   | Before/Equal   | SKIP     |
// | Exists         | Not exists     | UPLOAD   |
// | Not exists     | Exists         | DOWNLOAD |
func Decide(entry FileEntry, lastSync *time.Time) Decision {
	localExists := entry.LocalInfo != nil
	remoteExists := entry.RemoteInfo != nil

	// One side doesn't exist
	if !localExists && remoteExists {
		return Decision{
			Entry:  entry,
			Action: ActionDownload,
			Reason: "file exists only on remote",
		}
	}
	if localExists && !remoteExists {
		return Decision{
			Entry:  entry,
			Action: ActionUpload,
			Reason: "file exists only locally",
		}
	}
	if !localExists && !remoteExists {
		// Should never happen
		return Decision{
			Entry:  entry,
			Action: ActionSkip,
			Reason: "file does not exist on either side",
		}
	}

	// First sync case (lastSync is nil): upload everything local
	if lastSync == nil {
		return Decision{
			Entry:  entry,
			Action: ActionUpload,
			Reason: "first sync - uploading local files",
		}
	}

	// Both exist: check modification times
	localMod := entry.LocalInfo.ModTime
	remoteMod := entry.RemoteInfo.ModTime

	localNewer := localMod.After(*lastSync)
	remoteNewer := remoteMod.After(*lastSync)

	switch {
	case localNewer && remoteNewer:
		return Decision{
			Entry:  entry,
			Action: ActionConflict,
			Reason: "both sides modified since last sync",
		}
	case localNewer:
		return Decision{
			Entry:  entry,
			Action: ActionUpload,
			Reason: "local file modified since last sync",
		}
	case remoteNewer:
		return Decision{
			Entry:  entry,
			Action: ActionDownload,
			Reason: "remote file modified since last sync",
		}
	default:
		return Decision{
			Entry:  entry,
			Action: ActionSkip,
			Reason: "file unchanged since last sync",
		}
	}
}

// DecideAll returns decisions for all files in the inventory.
func DecideAll(inventory *Inventory) []Decision {
	var decisions []Decision
	for _, entry := range inventory.Files {
		decisions = append(decisions, Decide(entry, inventory.LastSync))
	}
	return decisions
}

// GroupByAction groups decisions by their action type.
func GroupByAction(decisions []Decision) map[Action][]Decision {
	groups := make(map[Action][]Decision)
	for _, d := range decisions {
		groups[d.Action] = append(groups[d.Action], d)
	}
	return groups
}

// CountByAction counts decisions by action type.
func CountByAction(decisions []Decision) map[Action]int {
	counts := make(map[Action]int)
	for _, d := range decisions {
		counts[d.Action]++
	}
	return counts
}
