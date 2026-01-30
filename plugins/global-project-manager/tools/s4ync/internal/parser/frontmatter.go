// Package parser handles YAML frontmatter parsing for markdown files.
package parser

import (
	"bytes"
	"errors"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

var (
	// ErrNoFrontmatter indicates the file has no frontmatter delimiter.
	ErrNoFrontmatter = errors.New("frontmatter delimiter not found")
	// ErrUnclosedFrontmatter indicates the frontmatter was not properly closed.
	ErrUnclosedFrontmatter = errors.New("frontmatter not properly closed")
)

// Frontmatter represents a parsed markdown file with YAML frontmatter.
type Frontmatter struct {
	node    *yaml.Node
	content string
}

// Parse extracts YAML frontmatter and content from markdown data.
// It preserves the YAML structure for round-trip editing.
func Parse(data []byte) (*Frontmatter, error) {
	if !bytes.HasPrefix(data, []byte("---\n")) && !bytes.HasPrefix(data, []byte("---\r\n")) {
		return nil, ErrNoFrontmatter
	}

	// Find the closing delimiter
	rest := data[4:] // Skip opening "---\n"
	idx := bytes.Index(rest, []byte("\n---\n"))
	if idx == -1 {
		// Try with CRLF
		idx = bytes.Index(rest, []byte("\r\n---\r\n"))
		if idx == -1 {
			// Check for EOF case (no trailing newline after ---)
			if bytes.HasSuffix(rest, []byte("\n---")) {
				idx = len(rest) - 4
			} else {
				return nil, ErrUnclosedFrontmatter
			}
		}
	}

	yamlData := rest[:idx]
	contentStart := min(idx+5, len(rest)) // Skip "\n---\n", bounded by length
	content := string(rest[contentStart:])

	// Parse YAML into a node to preserve structure
	var node yaml.Node
	if err := yaml.Unmarshal(yamlData, &node); err != nil {
		return nil, err
	}

	return &Frontmatter{
		node:    &node,
		content: content,
	}, nil
}

// Get retrieves a field value from frontmatter.
func (f *Frontmatter) Get(key string) any {
	if f.node == nil || len(f.node.Content) == 0 {
		return nil
	}

	// The root node contains a document node, which contains the mapping
	mapping := f.node.Content[0]
	if mapping.Kind != yaml.MappingNode {
		return nil
	}

	for i := 0; i < len(mapping.Content); i += 2 {
		if mapping.Content[i].Value == key {
			return nodeToValue(mapping.Content[i+1])
		}
	}
	return nil
}

// GetString retrieves a string field value from frontmatter.
func (f *Frontmatter) GetString(key string) string {
	val := f.Get(key)
	if s, ok := val.(string); ok {
		return s
	}
	return ""
}

// GetTime retrieves a time field value from frontmatter.
func (f *Frontmatter) GetTime(key string) *time.Time {
	val := f.Get(key)
	if val == nil {
		return nil
	}

	switch v := val.(type) {
	case time.Time:
		return &v
	case string:
		if v == "" || v == "null" {
			return nil
		}
		t, err := time.Parse(time.RFC3339, v)
		if err != nil {
			return nil
		}
		return &t
	}
	return nil
}

// Set updates a field in frontmatter.
func (f *Frontmatter) Set(key string, value any) {
	if f.node == nil || len(f.node.Content) == 0 {
		// Initialize empty document
		f.node = &yaml.Node{
			Kind: yaml.DocumentNode,
			Content: []*yaml.Node{
				{Kind: yaml.MappingNode},
			},
		}
	}

	mapping := f.node.Content[0]
	if mapping.Kind != yaml.MappingNode {
		return
	}

	// Find existing key
	for i := 0; i < len(mapping.Content); i += 2 {
		if mapping.Content[i].Value == key {
			mapping.Content[i+1] = valueToNode(value)
			return
		}
	}

	// Add new key-value pair
	mapping.Content = append(mapping.Content,
		&yaml.Node{Kind: yaml.ScalarNode, Value: key},
		valueToNode(value),
	)
}

// Content returns the markdown body after frontmatter.
func (f *Frontmatter) Content() string {
	return f.content
}

// SetContent updates the markdown body.
func (f *Frontmatter) SetContent(content string) {
	f.content = content
}

// Marshal converts frontmatter back to markdown with preserved YAML formatting.
func (f *Frontmatter) Marshal() ([]byte, error) {
	var buf bytes.Buffer

	buf.WriteString("---\n")

	if f.node != nil && len(f.node.Content) > 0 {
		encoder := yaml.NewEncoder(&buf)
		encoder.SetIndent(2)
		if err := encoder.Encode(f.node); err != nil {
			return nil, err
		}
		encoder.Close()
	}

	// Remove trailing newline from YAML encoder if present, then add delimiter
	data := buf.Bytes()
	if len(data) > 0 && data[len(data)-1] == '\n' {
		data = data[:len(data)-1]
	}

	var result bytes.Buffer
	result.Write(data)
	result.WriteString("\n---\n")
	result.WriteString(f.content)

	return result.Bytes(), nil
}

// nodeToValue converts a yaml.Node to a Go value.
func nodeToValue(node *yaml.Node) any {
	switch node.Kind {
	case yaml.ScalarNode:
		// Check for null
		if node.Tag == "!!null" || node.Value == "null" || node.Value == "~" {
			return nil
		}
		// Try to decode as time
		var t time.Time
		if err := node.Decode(&t); err == nil && node.Tag == "!!timestamp" {
			return t
		}
		// Try to decode as bool
		if node.Tag == "!!bool" || node.Value == "true" || node.Value == "false" {
			return node.Value == "true"
		}
		return node.Value
	case yaml.SequenceNode:
		var result []any
		for _, child := range node.Content {
			result = append(result, nodeToValue(child))
		}
		return result
	case yaml.MappingNode:
		result := make(map[string]any)
		for i := 0; i < len(node.Content); i += 2 {
			key := node.Content[i].Value
			result[key] = nodeToValue(node.Content[i+1])
		}
		return result
	}
	return nil
}

// valueToNode converts a Go value to a yaml.Node.
func valueToNode(value any) *yaml.Node {
	node := &yaml.Node{}

	switch v := value.(type) {
	case nil:
		node.Kind = yaml.ScalarNode
		node.Tag = "!!null"
		node.Value = "null"
	case string:
		node.Kind = yaml.ScalarNode
		node.Value = v
	case bool:
		node.Kind = yaml.ScalarNode
		node.Tag = "!!bool"
		if v {
			node.Value = "true"
		} else {
			node.Value = "false"
		}
	case int, int64:
		node.Kind = yaml.ScalarNode
		node.Tag = "!!int"
		node.SetString(strings.TrimSpace(strings.ReplaceAll(
			strings.ReplaceAll(valueString(v), "\n", ""), " ", "")))
	case time.Time:
		node.Kind = yaml.ScalarNode
		node.Value = v.Format(time.RFC3339)
	case *time.Time:
		if v == nil {
			node.Kind = yaml.ScalarNode
			node.Tag = "!!null"
			node.Value = "null"
		} else {
			node.Kind = yaml.ScalarNode
			node.Value = v.Format(time.RFC3339)
		}
	default:
		// Fallback: marshal and unmarshal
		data, _ := yaml.Marshal(value)
		yaml.Unmarshal(data, node)
	}

	return node
}

func valueString(v any) string {
	switch val := v.(type) {
	case int:
		return string(rune(val))
	case int64:
		return string(rune(val))
	default:
		return ""
	}
}
