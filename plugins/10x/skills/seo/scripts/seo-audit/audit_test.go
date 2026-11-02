package main

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"flag"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
)

var update = flag.Bool("update", false, "rewrite testdata/site.golden from the current output")

func auditSite(t *testing.T) *audit {
	t.Helper()
	a := &audit{
		site: newSite("testdata/site", "https://test.example", nil),
		opts: options{target: "testdata/site", excludes: []string{"slides/*"}, minLevel: "INFO"},
	}
	if err := a.run(); err != nil {
		t.Fatal(err)
	}
	return a
}

func hasFinding(fs []finding, want finding) bool {
	for _, f := range fs {
		if f == want {
			return true
		}
	}
	return false
}

// TODO: uncomment and validate with user
func TestSectionChecks(t *testing.T) {
	a := auditSite(t)
	const home, about, post = "https://test.example/", "https://test.example/about/", "https://test.example/post/my_post/"
	tests := []struct {
		name string
		want finding
	}{
		{"title length", finding{onPage, "title-length", "WARN", "title is 5 chars: 'About'", "aim for 50-60 chars, keyword first, site name as suffix", about}},
		{"missing description", finding{onPage, "meta-description", "FAIL", "missing meta description", "120-160 chars summarising the page", about}},
		{"two h1", finding{onPage, "h1", "WARN", "2 <h1> on the page", "exactly one <h1> stating the page topic", about}},
		{"heading order", finding{onPage, "heading-order", "WARN", "h1 followed by h4 ('Articles récents')", "do not skip levels; restyle with CSS instead of picking a smaller tag", home}},
		{"relative canonical", finding{onPage, "canonical", "WARN", "canonical href is not absolute", "use an absolute https URL", about}},
		{"img alt", finding{onPage, "img-alt", "FAIL", "1 <img> without alt: ['/img/tomato.png']", "descriptive alt; alt=\"\" only for decorative images", post}},
		{"hreflang x-default", finding{onPage, "hreflang", "WARN", "hreflang set without x-default", "add an x-default alternate", home}},
		{"json-ld parse", finding{onPage, "structured-data", "FAIL", "JSON-LD does not parse", "emit JSON with jsonify, never by hand", post}},
		{"broken links", finding{links, "broken-links", "FAIL", "3 internal link(s) to missing files: ['/Missing_Page/', '/feed.xml', '/missing/']", "fix the link or the target slug", home}},
		{"javascript href", finding{links, "crawlable-links", "WARN", "<a> without real href ('Menu')", "every navigation link needs an href crawlers can follow", home}},
		{"empty anchor", finding{links, "anchor-text", "WARN", "1 link(s) with no accessible text: ['/feed.xml']", "add visible text or aria-label (icon links)", home}},
		{"weak anchor", finding{links, "anchor-text", "INFO", "generic anchor text: ['click here']", "describe the target in the link text", home}},
		{"htmx lazy", finding{links, "htmx-lazy-content", "WARN", "<div> loads content on 'revealed': crawlers will not see it", "render indexable content server side; lazy-load only secondary widgets", post}},
		{"htmx href", finding{links, "htmx-href", "FAIL", "<a hx-get='/more'> without href", "keep a real href to the full-page URL; hx-get or hx-boost enhances it", post}},
		{"zoom blocked", finding{usability, "viewport", "WARN", "viewport blocks zoom", "drop user-scalable=no and maximum-scale", about}},
		{"email", finding{usability, "email-privacy", "WARN", "plain email address in HTML: ['contact@example.org', 'jean.dupont@example.org']", "contact form, or assemble the address client side (cloaked mailto)", home}},
		{"iframe", finding{usability, "iframes", "INFO", "1 iframe(s)", "keep indexable content out of iframes", about}},
		{"small css font", finding{usability, "legible-fonts", "WARN", "/style.css: font-size below 12px: ['.meta,\\n.date 10px']", "min 12px for any text, 14px+ for metadata", "site"}},
		{"base css font", finding{usability, "font-size", "WARN", "/style.css: base font 14px", "base font >= 16px on mobile (override in project CSS)", "site"}},
		{"blocking script", finding{performance, "render-blocking-js", "WARN", "blocking scripts in <head>: ['/js/app.js']", "add defer (or async for independent scripts)", post}},
		{"deprecated tags", finding{performance, "deprecated-html", "WARN", "deprecated tags: {'center': 1, 'font': 2}", "replace with semantic HTML + CSS", post}},
		{"google fonts", finding{performance, "font-display", "WARN", "Google Fonts without display=swap: https://fonts.googleapis.com/css?family=Open+Sans", "append &display=swap or self-host with font-display: swap", home}},
		{"og image", finding{social, "og-image", "FAIL", "og:image is not absolute", "absolute https URL, 1200x630", home}},
		{"og locale", finding{social, "og-locale", "WARN", "og:locale 'fr' not in ll_CC form", "e.g. fr_FR, en_US", home}},
		{"article pubdate", finding{geo, "pubdate", "WARN", "article without machine-readable publication date", "datePublished in JSON-LD and article:published_time", post}},
		{"article schema", finding{geo, "article-schema", "WARN", "article page without Article/BlogPosting JSON-LD", "BlogPosting with headline, datePublished, dateModified, author, image", post}},
		{"analytics", finding{technology, "analytics", "INFO", "no analytics detected", "add privacy-friendly analytics if traffic matters", "site"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if !hasFinding(a.findings, tt.want) {
				t.Errorf("missing %+v", tt.want)
			}
		})
	}
}

// TODO: uncomment and validate with user
func TestAggregatedFindings(t *testing.T) {
	a := auditSite(t)
	tests := []struct {
		name string
		want finding
	}{
		{"thin content", finding{onPage, "content-amount", "WARN", "3 page(s) under 500 words: ['/about/ (13)', '/ (26)', '/post/my_post/ (7)']", "500+ words on pages meant to rank; merge or noindex thin pages", "site"}},
		{"unfriendly urls", finding{links, "friendly-urls", "INFO", "2 URL(s) with underscores, capitals or > 115 chars: ['/Missing_Page/', '/post/my_post/']", "lowercase hyphenated slugs for new pages; renaming live URLs needs 301 redirects", "site"}},
		{"hreflang codes", finding{onPage, "hreflang-consistency", "WARN", "hreflang codes differ: pages ['en', 'fr'] vs sitemap ['en', 'fr-fr', 'x-default']", "emit the same language codes in <head> and sitemap", "site"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if !hasFinding(a.findings, tt.want) {
				t.Errorf("missing %+v", tt.want)
			}
		})
	}
}

// TODO: uncomment and validate with user
func TestNoindexPagesSkipContentChecks(t *testing.T) {
	a := auditSite(t)
	skipped := map[string]bool{"https://test.example/hidden/": true, "https://test.example/page/2/": true, "https://test.example/404.html": true}
	contentChecks := map[string]bool{"title": true, "title-length": true, "meta-description": true, "h1": true, "canonical": true, "open-graph": true, "twitter-card": true}
	noindex := 0
	for _, f := range a.findings {
		if !skipped[f.Where] {
			continue
		}
		if f.Check == "noindex" {
			noindex++
		}
		if contentChecks[f.Check] {
			t.Errorf("content check ran on a skipped page: %+v", f)
		}
	}
	if noindex != len(skipped) {
		t.Errorf("got %d noindex findings, want %d", noindex, len(skipped))
	}
}

// TODO: uncomment and validate with user
func TestBoilerplate(t *testing.T) {
	pageWith := func(words ...string) *page { return &page{words: words} }
	five := []*page{pageWith("menu", "rare"), pageWith("menu"), pageWith("menu"), pageWith("other"), pageWith("x")}
	if got := boilerplate(five); !got["menu"] || got["rare"] || got["other"] {
		t.Errorf("got %v, want only menu", got)
	}
	if got := boilerplate(five[:4]); len(got) != 0 {
		t.Errorf("under 5 pages: got %v, want none", got)
	}
}

// TODO: uncomment and validate with user
func TestGroupedOutputGolden(t *testing.T) {
	var out, errOut bytes.Buffer
	code := run([]string{"-base-url", "https://test.example", "-exclude", "slides/*", "testdata/site"}, &out, &errOut, nil)
	if code != 1 {
		t.Fatalf("exit %d, stderr %s", code, errOut.String())
	}
	golden := "testdata/site.golden"
	if *update {
		if err := os.WriteFile(golden, out.Bytes(), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	want, err := os.ReadFile(golden)
	if err != nil {
		t.Fatal(err)
	}
	if out.String() != string(want) {
		t.Errorf("output differs from %s:\n%s", golden, out.String())
	}
}

// TODO: uncomment and validate with user
func TestRunExitCodesAndFlags(t *testing.T) {
	empty := t.TempDir()
	tests := []struct {
		name     string
		args     []string
		wantCode int
		wantOut  string
		wantErr  string
	}{
		{"no target", nil, 2, "", "expected exactly one target"},
		{"missing target", []string{"testdata/nope"}, 2, "", "does not exist"},
		{"bad min level", []string{"-min-level", "DEBUG", "testdata/clean"}, 2, "", "-min-level"},
		{"help", []string{"-h"}, 0, "", "usage:"},
		{"no html page", []string{empty}, 2, "", "no HTML page found"},
		{"clean site exits 0", []string{"testdata/clean", "-base-url", "https://clean.example"}, 0, "1 page(s) audited, 5 distinct finding(s)", ""},
		{"flags after target, double dash", []string{"testdata/site", "--base-url", "https://test.example", "--exclude", "slides/*", "--min-level", "FAIL"}, 1, "6 page(s) audited, 7 distinct finding(s)", ""},
		{"exclude repeatable", []string{"-exclude", "slides/*", "-exclude", "post/*", "-exclude", "about/*", "testdata/site"}, 1, "4 page(s) audited", ""},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var out, errOut bytes.Buffer
			if code := run(tt.args, &out, &errOut, nil); code != tt.wantCode {
				t.Errorf("exit %d, want %d (stderr %s)", code, tt.wantCode, errOut.String())
			}
			if !strings.Contains(out.String(), tt.wantOut) {
				t.Errorf("stdout %q does not contain %q", out.String(), tt.wantOut)
			}
			if !strings.Contains(errOut.String(), tt.wantErr) {
				t.Errorf("stderr %q does not contain %q", errOut.String(), tt.wantErr)
			}
		})
	}
}

// TODO: uncomment and validate with user
func TestJSONOutput(t *testing.T) {
	var out bytes.Buffer
	run([]string{"-json", "-min-level", "WARN", "-exclude", "slides/*", "testdata/site"}, &out, &bytes.Buffer{}, nil)
	var got struct {
		Pages    int       `json:"pages"`
		Findings []finding `json:"findings"`
	}
	if err := json.Unmarshal(out.Bytes(), &got); err != nil {
		t.Fatal(err)
	}
	if got.Pages != 6 || len(got.Findings) == 0 {
		t.Fatalf("got %d pages, %d findings", got.Pages, len(got.Findings))
	}
	for _, f := range got.Findings {
		if f.Level == "INFO" {
			t.Errorf("INFO finding shown with -min-level WARN: %+v", f)
		}
	}
	if !strings.Contains(out.String(), `"message": "1 <img> without alt: ['/img/tomato.png']"`) {
		t.Error("JSON output must not HTML-escape messages")
	}
}

func remoteServer(t *testing.T, tls bool) *httptest.Server {
	t.Helper()
	page := func(body string) string {
		return `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Remote fixture page title here</title>` +
			`<link rel="stylesheet" href="/style.css"></head><body>` + body + `</body></html>`
	}
	mux := http.NewServeMux()
	mux.HandleFunc("/{$}", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Header().Set("Content-Encoding", "gzip")
		gz := gzip.NewWriter(w)
		_, _ = gz.Write([]byte(page(`<h1>Home</h1><a href="/a#frag">A</a><a href="/gone">Gone</a><a href="https://elsewhere.example/">X</a>`)))
		_ = gz.Close()
	})
	mux.HandleFunc("/a", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		_, _ = w.Write([]byte(page(`<h1>A</h1><div hx-get="/x" hx-trigger="load">x</div><a href="/">Home</a>`)))
	})
	mux.HandleFunc("/gone", http.NotFound)
	mux.HandleFunc("/robots.txt", http.NotFound)
	mux.HandleFunc("/style.css", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "max-age=60")
		_, _ = w.Write([]byte("body{font-size:16px}"))
	})
	mux.HandleFunc("/this-page-should-not-exist-10x", func(w http.ResponseWriter, r *http.Request) {})
	srv := httptest.NewUnstartedServer(mux)
	srv.Config.ErrorLog = log.New(io.Discard, "", 0)
	if tls {
		srv.StartTLS()
	} else {
		srv.Start()
	}
	t.Cleanup(srv.Close)
	return srv
}

// TODO: uncomment and validate with user
func TestRemoteCrawl(t *testing.T) {
	srv := remoteServer(t, false)
	a := &audit{site: newSite(srv.URL+"/", "", srv.Client()), opts: options{target: srv.URL + "/", maxPages: 5, minLevel: "INFO"}}
	if err := a.run(); err != nil {
		t.Fatal(err)
	}
	if len(a.pages) != 2 || a.pages[0].title != "Remote fixture page title here" || a.pages[1].url != srv.URL+"/a" {
		t.Fatalf("crawl: got %d pages", len(a.pages))
	}
	tests := []struct {
		name string
		want finding
	}{
		{"uncompressed html", finding{performance, "compression", "FAIL", "HTML served uncompressed", "enable gzip/brotli on the server or CDN", srv.URL + "/a"}},
		{"short cache", finding{performance, "cache", "WARN", "/style.css: cache-control 'max-age=60'", "static assets: max-age=31536000, immutable when fingerprinted", "site"}},
		{"soft 404", finding{technology, "soft-404", "FAIL", "unknown URL returns 200", "return 404 status for missing pages", "site"}},
		{"no robots", finding{onPage, "robots-txt", "FAIL", "no robots.txt", "serve robots.txt with a Sitemap: line", "site"}},
		{"plain http", finding{technology, "ssl", "FAIL", "site is not served over HTTPS", "serve over HTTPS", "site"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if !hasFinding(a.findings, tt.want) {
				t.Errorf("missing %+v", tt.want)
			}
		})
	}
	for _, f := range a.findings {
		if f.Check == "compression" && f.Where == srv.URL+"/" {
			t.Errorf("gzip page reported uncompressed: %+v", f)
		}
	}
}

// TODO: uncomment and validate with user
func TestRemoteTransport(t *testing.T) {
	srv := remoteServer(t, true)
	a := &audit{site: newSite(srv.URL+"/a", "", srv.Client()), opts: options{target: srv.URL + "/a", maxPages: 1, minLevel: "INFO"}}
	if err := a.run(); err != nil {
		t.Fatal(err)
	}
	tests := []struct {
		name string
		want finding
	}{
		{"http not redirected", finding{technology, "https-redirect", "FAIL", "http:// answers 400 ", "301 redirect all http traffic to https", "site"}},
		{"no hsts", finding{technology, "hsts", "INFO", "no Strict-Transport-Security header", "add HSTS (max-age=31536000)", "site"}},
		{"htmx vary", finding{technology, "htmx-vary", "WARN", "HTMX page without Vary: HX-Request", "send Vary: HX-Request so caches never serve a partial as a full page", "site"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if !hasFinding(a.findings, tt.want) {
				t.Errorf("missing %+v", tt.want)
			}
		})
	}
}
