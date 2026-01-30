package parser_test

import (
	"strings"
	"testing"
	"time"

	"github.com/arhuman/s4ync/internal/parser"
)

func TestParse(t *testing.T) {
	tests := []struct {
		name      string
		input     string
		wantErr   error
		checkFunc func(*testing.T, *parser.Frontmatter)
	}{
		{
			name: "valid frontmatter",
			input: `---
shortname: test-project
name: Test Project
created_at: 2026-01-29T10:00:00Z
last_sync: null
---

# Content here
`,
			wantErr: nil,
			checkFunc: func(t *testing.T, fm *parser.Frontmatter) {
				if fm.GetString("shortname") != "test-project" {
					t.Errorf("expected shortname 'test-project', got %q", fm.GetString("shortname"))
				}
				if fm.GetString("name") != "Test Project" {
					t.Errorf("expected name 'Test Project', got %q", fm.GetString("name"))
				}
				if fm.GetTime("last_sync") != nil {
					t.Errorf("expected last_sync to be nil, got %v", fm.GetTime("last_sync"))
				}
				if !strings.Contains(fm.Content(), "# Content here") {
					t.Errorf("expected content to contain '# Content here'")
				}
			},
		},
		{
			name: "frontmatter with timestamp",
			input: `---
created_at: 2026-01-29T10:00:00Z
last_sync: 2026-01-29T15:30:00Z
---

Body
`,
			wantErr: nil,
			checkFunc: func(t *testing.T, fm *parser.Frontmatter) {
				lastSync := fm.GetTime("last_sync")
				if lastSync == nil {
					t.Fatal("expected last_sync to be non-nil")
				}
				expected := time.Date(2026, 1, 29, 15, 30, 0, 0, time.UTC)
				if !lastSync.Equal(expected) {
					t.Errorf("expected last_sync %v, got %v", expected, lastSync)
				}
			},
		},
		{
			name:    "no frontmatter",
			input:   "# Just markdown\n\nNo frontmatter here.",
			wantErr: parser.ErrNoFrontmatter,
		},
		{
			name: "unclosed frontmatter",
			input: `---
key: value
No closing delimiter`,
			wantErr: parser.ErrUnclosedFrontmatter,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fm, err := parser.Parse([]byte(tt.input))

			if tt.wantErr != nil {
				if err != tt.wantErr {
					t.Errorf("expected error %v, got %v", tt.wantErr, err)
				}
				return
			}

			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}

			if tt.checkFunc != nil {
				tt.checkFunc(t, fm)
			}
		})
	}
}

func TestSet(t *testing.T) {
	input := `---
shortname: test
last_sync: null
---

Content
`

	fm, err := parser.Parse([]byte(input))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Set a new timestamp
	newTime := time.Date(2026, 1, 30, 12, 0, 0, 0, time.UTC)
	fm.Set("last_sync", newTime)

	// Verify it was set
	lastSync := fm.GetTime("last_sync")
	if lastSync == nil {
		t.Fatal("expected last_sync to be non-nil after setting")
	}
	if !lastSync.Equal(newTime) {
		t.Errorf("expected last_sync %v, got %v", newTime, lastSync)
	}
}

func TestMarshal(t *testing.T) {
	input := `---
shortname: test-project
name: Test Project
last_sync: null
---

# Heading

Some content.
`

	fm, err := parser.Parse([]byte(input))
	if err != nil {
		t.Fatalf("unexpected error parsing: %v", err)
	}

	// Update last_sync
	newTime := time.Date(2026, 1, 30, 12, 0, 0, 0, time.UTC)
	fm.Set("last_sync", newTime)

	// Marshal back
	data, err := fm.Marshal()
	if err != nil {
		t.Fatalf("unexpected error marshaling: %v", err)
	}

	result := string(data)

	// Verify structure preserved
	if !strings.Contains(result, "shortname: test-project") {
		t.Error("expected shortname to be preserved")
	}
	if !strings.Contains(result, "name: Test Project") {
		t.Error("expected name to be preserved")
	}
	if !strings.Contains(result, "2026-01-30T12:00:00Z") {
		t.Error("expected updated last_sync timestamp")
	}
	if !strings.Contains(result, "# Heading") {
		t.Error("expected content to be preserved")
	}
	if !strings.Contains(result, "Some content.") {
		t.Error("expected content body to be preserved")
	}
}

func TestRoundTrip(t *testing.T) {
	// Test that parsing and marshaling produces valid output
	original := `---
shortname: claude-plugin
name: claude-plugin
created_at: 2026-01-29T10:00:00Z
last_sync: null
git_repo: git@github.com:arhuman/claude-plugin.git
jj_repo: true
---

# claude-plugin

Project description.
`

	fm, err := parser.Parse([]byte(original))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	data, err := fm.Marshal()
	if err != nil {
		t.Fatalf("unexpected error marshaling: %v", err)
	}

	// Parse again
	fm2, err := parser.Parse(data)
	if err != nil {
		t.Fatalf("unexpected error re-parsing: %v", err)
	}

	// Verify fields preserved
	if fm2.GetString("shortname") != "claude-plugin" {
		t.Errorf("shortname not preserved: got %q", fm2.GetString("shortname"))
	}
	if !strings.Contains(fm2.Content(), "# claude-plugin") {
		t.Error("content not preserved")
	}
}

func TestGetNonExistent(t *testing.T) {
	input := `---
key: value
---

Content
`
	fm, err := parser.Parse([]byte(input))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if fm.Get("nonexistent") != nil {
		t.Error("expected nil for non-existent key")
	}
	if fm.GetString("nonexistent") != "" {
		t.Error("expected empty string for non-existent key")
	}
	if fm.GetTime("nonexistent") != nil {
		t.Error("expected nil time for non-existent key")
	}
}
