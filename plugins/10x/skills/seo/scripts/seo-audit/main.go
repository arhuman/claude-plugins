// Command seo-audit audits a built site directory, a single HTML file, or a
// live URL for the checks of a SEOptimer-style report: On-Page SEO, Links,
// Usability, Performance, Social, GEO and Technology.
//
//	seo-audit -base-url https://example.com public/
//	seo-audit -max-pages 20 https://example.com
//	seo-audit -json page.html
//
// Exit status: 0 no FAIL finding, 1 at least one FAIL, 2 usage error.
package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"sort"
	"strings"
	"time"
)

var rank = map[string]int{"INFO": 0, "WARN": 1, "FAIL": 2}

func main() {
	os.Exit(run(os.Args[1:], os.Stdout, os.Stderr, &http.Client{Timeout: 20 * time.Second}))
}

// multiFlag collects a repeatable string flag.
type multiFlag []string

func (m *multiFlag) String() string     { return strings.Join(*m, ",") }
func (m *multiFlag) Set(v string) error { *m = append(*m, v); return nil }

func parseArgs(args []string, stderr io.Writer) (options, error) {
	opts := options{}
	fs := flag.NewFlagSet("seo-audit", flag.ContinueOnError)
	fs.SetOutput(stderr)
	fs.StringVar(&opts.baseURL, "base-url", "", "public URL of a directory target (canonical, sitemap, hreflang)")
	fs.IntVar(&opts.maxPages, "max-pages", 1, "pages to crawl for a URL target")
	fs.Var((*multiFlag)(&opts.excludes), "exclude", "skip directory files matching GLOB, relative to the target (repeatable), e.g. 'slides/*'")
	fs.BoolVar(&opts.json, "json", false, "machine-readable output")
	fs.StringVar(&opts.minLevel, "min-level", "INFO", "lowest level shown: INFO, WARN or FAIL")
	fs.Usage = func() {
		fmt.Fprintln(stderr, "usage: seo-audit [flags] <dir|file|url> [flags]")
		fs.PrintDefaults()
	}
	var positional []string
	for {
		if err := fs.Parse(args); err != nil {
			return opts, err
		}
		if fs.NArg() == 0 {
			break
		}
		positional = append(positional, fs.Arg(0))
		args = fs.Args()[1:]
	}
	if len(positional) != 1 {
		return opts, usageError(fs, "expected exactly one target: built site directory, HTML file, or http(s) URL")
	}
	opts.target = positional[0]
	if _, ok := rank[opts.minLevel]; !ok {
		return opts, usageError(fs, "-min-level must be INFO, WARN or FAIL")
	}
	if !isURL(opts.target) {
		if _, err := os.Stat(opts.target); err != nil {
			return opts, usageError(fs, opts.target+" does not exist")
		}
	}
	return opts, nil
}

func usageError(fs *flag.FlagSet, msg string) error {
	fs.Usage()
	return errors.New(msg)
}

// run executes the CLI and returns the exit status.
func run(args []string, stdout, stderr io.Writer, client *http.Client) int {
	opts, err := parseArgs(args, stderr)
	if errors.Is(err, flag.ErrHelp) {
		return 0
	}
	if err != nil {
		fmt.Fprintln(stderr, "seo-audit: error:", err)
		return 2
	}
	a := &audit{site: newSite(opts.target, opts.baseURL, client), opts: opts}
	if err := a.run(); err != nil {
		fmt.Fprintln(stderr, err)
		return 2
	}
	shown := []finding{}
	for _, f := range a.findings {
		if rank[f.Level] >= rank[opts.minLevel] {
			shown = append(shown, f)
		}
	}
	if opts.json {
		enc := json.NewEncoder(stdout)
		enc.SetEscapeHTML(false)
		enc.SetIndent("", "  ")
		_ = enc.Encode(struct {
			Pages    int       `json:"pages"`
			Findings []finding `json:"findings"`
		}{len(a.pages), shown})
	} else {
		printGrouped(stdout, len(a.pages), shown)
	}
	for _, f := range a.findings {
		if f.Level == "FAIL" {
			return 1
		}
	}
	return 0
}

// printGrouped merges findings that differ only by page, then lists them per
// section, FAIL first, by check id.
func printGrouped(w io.Writer, pages int, findings []finding) {
	type key struct{ section, check, level, message, fix string }
	var order []key
	where := map[key][]string{}
	for _, f := range findings {
		k := key{f.Section, f.Check, f.Level, f.Message, f.Fix}
		if _, seen := where[k]; !seen {
			order = append(order, k)
		}
		where[k] = append(where[k], f.Where)
	}
	fmt.Fprintf(w, "%d page(s) audited, %d distinct finding(s)\n", pages, len(order))
	for _, section := range sections {
		var items []key
		for _, k := range order {
			if k.section == section {
				items = append(items, k)
			}
		}
		sort.SliceStable(items, func(i, j int) bool {
			if rank[items[i].level] != rank[items[j].level] {
				return rank[items[i].level] > rank[items[j].level]
			}
			return items[i].check < items[j].check
		})
		if len(items) > 0 {
			fmt.Fprintf(w, "\n## %s\n", section)
		}
		for _, k := range items {
			at := where[k][0]
			if n := len(where[k]); n > 1 {
				at = fmt.Sprintf("%d pages, e.g. %s", n, at)
			}
			fmt.Fprintf(w, "%-4s %-22s %s\n     fix: %s  [%s]\n", k.level, k.check, k.message, k.fix, at)
		}
	}
}
