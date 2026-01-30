package sync_test

import (
	"testing"
	"time"

	"github.com/arhuman/s4ync/internal/storage"
	"github.com/arhuman/s4ync/internal/sync"
)

func TestDecide(t *testing.T) {
	baseTime := time.Date(2026, 1, 29, 10, 0, 0, 0, time.UTC)
	beforeSync := baseTime.Add(-1 * time.Hour)
	afterSync := baseTime.Add(1 * time.Hour)

	tests := []struct {
		name       string
		localMod   *time.Time
		remoteMod  *time.Time
		lastSync   *time.Time
		wantAction sync.Action
	}{
		{
			name:       "local only - upload",
			localMod:   &afterSync,
			remoteMod:  nil,
			lastSync:   &baseTime,
			wantAction: sync.ActionUpload,
		},
		{
			name:       "remote only - download",
			localMod:   nil,
			remoteMod:  &afterSync,
			lastSync:   &baseTime,
			wantAction: sync.ActionDownload,
		},
		{
			name:       "both modified - conflict",
			localMod:   &afterSync,
			remoteMod:  &afterSync,
			lastSync:   &baseTime,
			wantAction: sync.ActionConflict,
		},
		{
			name:       "local modified - upload",
			localMod:   &afterSync,
			remoteMod:  &beforeSync,
			lastSync:   &baseTime,
			wantAction: sync.ActionUpload,
		},
		{
			name:       "remote modified - download",
			localMod:   &beforeSync,
			remoteMod:  &afterSync,
			lastSync:   &baseTime,
			wantAction: sync.ActionDownload,
		},
		{
			name:       "neither modified - skip",
			localMod:   &beforeSync,
			remoteMod:  &beforeSync,
			lastSync:   &baseTime,
			wantAction: sync.ActionSkip,
		},
		{
			name:       "first sync (nil lastSync) - upload",
			localMod:   &afterSync,
			remoteMod:  &beforeSync,
			lastSync:   nil,
			wantAction: sync.ActionUpload,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			entry := sync.FileEntry{RelPath: "test.md"}

			if tt.localMod != nil {
				entry.LocalInfo = &storage.FileInfo{
					Path:    "test.md",
					ModTime: *tt.localMod,
					Size:    100,
				}
			}

			if tt.remoteMod != nil {
				entry.RemoteInfo = &storage.FileInfo{
					Path:    "test.md",
					ModTime: *tt.remoteMod,
					Size:    100,
				}
			}

			decision := sync.Decide(entry, tt.lastSync)

			if decision.Action != tt.wantAction {
				t.Errorf("Decide() = %v, want %v (reason: %s)",
					decision.Action, tt.wantAction, decision.Reason)
			}
		})
	}
}

func TestDecideAll(t *testing.T) {
	baseTime := time.Date(2026, 1, 29, 10, 0, 0, 0, time.UTC)
	beforeSync := baseTime.Add(-1 * time.Hour)
	afterSync := baseTime.Add(1 * time.Hour)

	inventory := &sync.Inventory{
		LastSync: &baseTime,
		Files: []sync.FileEntry{
			{
				RelPath: "local-only.md",
				LocalInfo: &storage.FileInfo{
					Path:    "local-only.md",
					ModTime: afterSync,
				},
			},
			{
				RelPath: "remote-only.md",
				RemoteInfo: &storage.FileInfo{
					Path:    "remote-only.md",
					ModTime: afterSync,
				},
			},
			{
				RelPath: "unchanged.md",
				LocalInfo: &storage.FileInfo{
					Path:    "unchanged.md",
					ModTime: beforeSync,
				},
				RemoteInfo: &storage.FileInfo{
					Path:    "unchanged.md",
					ModTime: beforeSync,
				},
			},
		},
	}

	decisions := sync.DecideAll(inventory)

	if len(decisions) != 3 {
		t.Errorf("expected 3 decisions, got %d", len(decisions))
	}

	counts := sync.CountByAction(decisions)

	if counts[sync.ActionUpload] != 1 {
		t.Errorf("expected 1 upload, got %d", counts[sync.ActionUpload])
	}
	if counts[sync.ActionDownload] != 1 {
		t.Errorf("expected 1 download, got %d", counts[sync.ActionDownload])
	}
	if counts[sync.ActionSkip] != 1 {
		t.Errorf("expected 1 skip, got %d", counts[sync.ActionSkip])
	}
}

func TestGroupByAction(t *testing.T) {
	decisions := []sync.Decision{
		{Entry: sync.FileEntry{RelPath: "a.md"}, Action: sync.ActionUpload},
		{Entry: sync.FileEntry{RelPath: "b.md"}, Action: sync.ActionUpload},
		{Entry: sync.FileEntry{RelPath: "c.md"}, Action: sync.ActionDownload},
		{Entry: sync.FileEntry{RelPath: "d.md"}, Action: sync.ActionSkip},
	}

	groups := sync.GroupByAction(decisions)

	if len(groups[sync.ActionUpload]) != 2 {
		t.Errorf("expected 2 uploads, got %d", len(groups[sync.ActionUpload]))
	}
	if len(groups[sync.ActionDownload]) != 1 {
		t.Errorf("expected 1 download, got %d", len(groups[sync.ActionDownload]))
	}
	if len(groups[sync.ActionSkip]) != 1 {
		t.Errorf("expected 1 skip, got %d", len(groups[sync.ActionSkip]))
	}
}
