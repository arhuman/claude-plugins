package main

import (
	"os"
	"reflect"
	"testing"
)

func loadPage(t *testing.T, path string) *page {
	t.Helper()
	src, err := readText(path)
	if err != nil {
		t.Fatal(err)
	}
	return parsePage("https://test.example/parse.html", src)
}

// TODO: uncomment and validate with user
func TestParsePage(t *testing.T) {
	p := loadPage(t, "testdata/pages/parse.html")
	anchorTexts := func(p *page) any {
		var out [][2]string
		for _, a := range p.anchors {
			out = append(out, [2]string{a.attrs["href"], a.text})
		}
		return out
	}
	tests := []struct {
		name string
		got  func(*page) any
		want any
	}{
		{"doctype", func(p *page) any { return p.doctype }, true},
		{"lang", func(p *page) any { return p.lang }, "en"},
		{"charset from http-equiv", func(p *page) any { return p.charset }, "ISO-8859-1"},
		{"first title, whitespace and nbsp collapsed", func(p *page) any { return p.title }, `It's a "parsing" fixture`},
		{"meta names lowercased, content kept", func(p *page) any { return p.metas }, map[string]string{"description": "  Parsing fixture  "}},
		{"og properties lowercased", func(p *page) any { return p.props }, map[string]string{"og:title": "Fixture"}},
		{"headings with nested text", func(p *page) any { return p.headings }, []heading{{1, "Main heading"}, {3, "Skipped level"}}},
		{"anchor text includes img alt", anchorTexts, [][2]string{{"/x", "level"}, {"/one", " Image alt and text"}, {"/two", ""}, {"", "no href"}}},
		{"json-ld blocks", func(p *page) any { return p.jsonld }, []string{
			`[{"@type":"Organization"},{"@type":["Person","Thing"]}]`,
			`{"@graph":[{"@type":"WebPage"},{"name":"untyped"}]}`,
		}},
		{"htmx attributes", func(p *page) any { return p.htmx }, []htmxTag{
			{tag: "div", hx: attrs{"hx-get": "/lazy", "hx-trigger": "load delay:1s"}},
			{tag: "button", hx: attrs{"data-hx-post": "/save"}},
			{tag: "a", hx: attrs{"hx-get": "/frag"}},
		}},
		{"deprecated tags in first-seen order", func(p *page) any { return p.deprecated }, []tagCount{{"font", 2}, {"center", 1}}},
		{"body words skip script, style, noscript and template", func(p *page) any { return p.words }, []string{
			"icon", "title", "main", "heading", "skipped", "level", "visible", "text", "with", "café", "words",
			"and", "text", "lazy", "save", "no", "href",
		}},
		{"img attributes", func(p *page) any { return p.imgs }, []attrs{{"src": "/i.png", "alt": "Image alt"}}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := tt.got(p); !reflect.DeepEqual(got, tt.want) {
				t.Errorf("got %#v, want %#v", got, tt.want)
			}
		})
	}
}

// TODO: uncomment and validate with user
func TestParsePageEdgeCases(t *testing.T) {
	tests := []struct {
		name string
		html string
		got  func(*page) any
		want any
	}{
		{"no doctype", "<html><title>x</title></html>", func(p *page) any { return p.doctype }, false},
		{"text without head counts as body", "<title>Only title</title><p>body</p>", func(p *page) any { return p.words }, []string{"only", "title", "body"}},
		{"head scripts flagged", "<head><script src=a.js></script></head><body><script src=b.js></script>", func(p *page) any {
			return []bool{p.scripts[0].inHead, p.scripts[1].inHead}
		}, []bool{true, false}},
		{"repeated attribute keeps first, as browsers do", `<a href="/a" href="/b">x</a>`, func(p *page) any { return p.anchors[0].attrs["href"] }, "/a"},
		{"valueless attribute present", "<script async src=x.js></script>", func(p *page) any { return p.scripts[0].attrs.has("async") }, true},
		{"inline style count", `<p style="a"><b style="b">x</b></p>`, func(p *page) any { return p.inlineStyles }, 2},
		{"iframe and embed counts", `<iframe></iframe><embed src=x><object></object>`, func(p *page) any { return []int{p.iframes, p.embeds} }, []int{1, 2}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := tt.got(parsePage("u", tt.html)); !reflect.DeepEqual(got, tt.want) {
				t.Errorf("got %#v, want %#v", got, tt.want)
			}
		})
	}
}

// TODO: uncomment and validate with user
func TestReadTextNormalizesNewlines(t *testing.T) {
	path := t.TempDir() + "/crlf.html"
	if err := os.WriteFile(path, []byte("a\r\nb\rc\xffd"), 0o600); err != nil {
		t.Fatal(err)
	}
	got, err := readText(path)
	if err != nil {
		t.Fatal(err)
	}
	if want := "a\nb\nc\uFFFDd"; got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}
