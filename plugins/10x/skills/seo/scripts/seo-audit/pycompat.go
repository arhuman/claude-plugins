package main

import (
	"fmt"
	"regexp"
	"sort"
	"strings"
	"unicode"
	"unicode/utf8"
)

// The helpers below reproduce the Python string semantics the report format
// was defined with (repr quoting, code point lengths, str.split), so messages
// stay byte-identical to the original Python auditor.

func pyIsSpace(r rune) bool {
	return unicode.IsSpace(r) || (r >= 0x1c && r <= 0x1f)
}

func pyStrip(s string) string { return strings.TrimFunc(s, pyIsSpace) }

func pyFields(s string) []string { return strings.FieldsFunc(s, pyIsSpace) }

func runeLen(s string) int { return utf8.RuneCountInString(s) }

func runeHead(s string, n int) string {
	i := 0
	for pos := range s {
		if i == n {
			return s[:pos]
		}
		i++
	}
	return s
}

func head[T any](s []T, n int) []T {
	if len(s) > n {
		return s[:n]
	}
	return s
}

// pyRepr formats s like Python repr(): single quotes unless the text holds a
// single quote and no double quote, non-printable characters escaped.
func pyRepr(s string) string {
	quote := '\''
	if strings.ContainsRune(s, '\'') && !strings.ContainsRune(s, '"') {
		quote = '"'
	}
	var b strings.Builder
	b.WriteRune(quote)
	for _, r := range s {
		switch {
		case r == quote || r == '\\':
			b.WriteByte('\\')
			b.WriteRune(r)
		case r == '\t':
			b.WriteString(`\t`)
		case r == '\n':
			b.WriteString(`\n`)
		case r == '\r':
			b.WriteString(`\r`)
		case r < 0x20 || r == 0x7f:
			fmt.Fprintf(&b, `\x%02x`, r)
		case r < 0x7f || unicode.IsPrint(r):
			b.WriteRune(r)
		case r <= 0xff:
			fmt.Fprintf(&b, `\x%02x`, r)
		case r <= 0xffff:
			fmt.Fprintf(&b, `\u%04x`, r)
		default:
			fmt.Fprintf(&b, `\U%08x`, r)
		}
	}
	b.WriteRune(quote)
	return b.String()
}

// pyList formats a string list like Python repr() of a list.
func pyList(items []string) string {
	quoted := make([]string, len(items))
	for i, s := range items {
		quoted[i] = pyRepr(s)
	}
	return "[" + strings.Join(quoted, ", ") + "]"
}

func sortedKeys(set map[string]bool) []string {
	keys := make([]string, 0, len(set))
	for k := range set {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

// mostCommon returns the n most frequent kept words; ties keep first-seen
// order, like collections.Counter.most_common.
func mostCommon(words []string, n int, keep func(string) bool) []string {
	counts := map[string]int{}
	var order []string
	for _, w := range words {
		if !keep(w) {
			continue
		}
		if counts[w] == 0 {
			order = append(order, w)
		}
		counts[w]++
	}
	sort.SliceStable(order, func(i, j int) bool { return counts[order[i]] > counts[order[j]] })
	return head(order, n)
}

// globRegexp translates a Python fnmatch pattern: '*' also matches '/',
// unlike path.Match.
func globRegexp(pat string) *regexp.Regexp {
	var b strings.Builder
	b.WriteString(`(?s)\A`)
	for i := 0; i < len(pat); i++ {
		switch c := pat[i]; c {
		case '*':
			for i+1 < len(pat) && pat[i+1] == '*' {
				i++
			}
			b.WriteString(".*")
		case '?':
			b.WriteString(".")
		case '[':
			j := i + 1
			if j < len(pat) && pat[j] == '!' {
				j++
			}
			if j < len(pat) && pat[j] == ']' {
				j++
			}
			for j < len(pat) && pat[j] != ']' {
				j++
			}
			if j >= len(pat) {
				b.WriteString(`\[`)
				continue
			}
			class := strings.ReplaceAll(pat[i+1:j], `\`, `\\`)
			if strings.HasPrefix(class, "!") {
				class = "^" + class[1:]
			} else if strings.HasPrefix(class, "^") || strings.HasPrefix(class, "[") {
				class = `\` + class
			}
			b.WriteString("[" + class + "]")
			i = j
		default:
			b.WriteString(regexp.QuoteMeta(pat[i : i+1]))
		}
	}
	b.WriteString(`\z`)
	re, err := regexp.Compile(b.String())
	if err != nil {
		return regexp.MustCompile(`\A` + regexp.QuoteMeta(pat) + `\z`)
	}
	return re
}
