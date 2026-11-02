package main

import (
	"reflect"
	"testing"
)

// TODO: uncomment and validate with user
func TestURLJoin(t *testing.T) {
	// Expected values come from Python's urllib.parse.urljoin.
	tests := []struct{ base, ref, want string }{
		{"https://a.b/c/d", "../x", "https://a.b/x"},
		{"https://a.b/c/d", "./", "https://a.b/c/"},
		{"https://a.b/c/d/", "e//f/../g", "https://a.b/c/d/e/g"},
		{"https://a.b/c/d?q=1#f", "#top", "https://a.b/c/d?q=1#top"},
		{"https://a.b/c/d?q=1", "?z", "https://a.b/c/d?z"},
		{"https://a.b/c", "//other.host/p", "https://other.host/p"},
		{"https://a.b/c", "mailto:x@y.z", "mailto:x@y.z"},
		{"https://a.b/c", "HTTP://A.B/Up", "HTTP://A.B/Up"},
		{"https://a.b/c", "  /trim\t me", "https://a.b/trim me"},
		{"https://a.b/c", "/a/b/..", "https://a.b/a/"},
		{"https://a.b/", "/../../etc", "https://a.b/etc"},
		{"https://a.b/x", "café/été", "https://a.b/café/été"},
		{"https://a.b/x", "", "https://a.b/x"},
	}
	for _, tt := range tests {
		t.Run(tt.base+" + "+tt.ref, func(t *testing.T) {
			if got := urlJoin(tt.base, tt.ref); got != tt.want {
				t.Errorf("got %q, want %q", got, tt.want)
			}
		})
	}
}

// TODO: uncomment and validate with user
func TestUnquoteAndDefrag(t *testing.T) {
	if got, want := unquote("/caf%C3%A9/%zz/%E2%82"), "/café/%zz/\uFFFD"; got != want {
		t.Errorf("unquote: got %q, want %q", got, want)
	}
	if got, want := urlDefrag("https://a.b/c?x#frag"), "https://a.b/c?x"; got != want {
		t.Errorf("urlDefrag: got %q, want %q", got, want)
	}
}

// TODO: uncomment and validate with user
func TestURLToFile(t *testing.T) {
	s := newSite("testdata/site", "https://test.example/", nil)
	tests := []struct{ url, want string }{
		{"/", "testdata/site/index.html"},
		{"https://test.example/about/", "testdata/site/about/index.html"},
		{"/about", "testdata/site/about/index.html"},
		{"/post/my%5Fpost/", "testdata/site/post/my_post/index.html"},
		{"/404", "testdata/site/404.html"},
		{"/style.css?v=1", "testdata/site/style.css"},
		{"/missing/", ""},
		{"https://other.example/about/", ""},
	}
	for _, tt := range tests {
		t.Run(tt.url, func(t *testing.T) {
			if got := s.urlToFile(tt.url); got != tt.want {
				t.Errorf("got %q, want %q", got, tt.want)
			}
		})
	}
}

// TODO: uncomment and validate with user
func TestIsInternal(t *testing.T) {
	s := newSite("testdata/site", "https://test.example", nil)
	tests := []struct {
		href string
		want bool
	}{
		{"/a", true},
		{"https://test.example/a", true},
		{"http://test.example/a", true},
		{"https://other.example/a", false},
		{"mailto:x@test.example", false},
	}
	for _, tt := range tests {
		t.Run(tt.href, func(t *testing.T) {
			if got := s.isInternal(tt.href); got != tt.want {
				t.Errorf("got %v, want %v", got, tt.want)
			}
		})
	}
}

// TODO: uncomment and validate with user
func TestReadSitemapsFollowsIndex(t *testing.T) {
	a := &audit{site: newSite("testdata/site", "https://test.example", nil)}
	locs, codes := a.readSitemaps([]string{"https://test.example/sitemap.xml"}, 0)
	if want := []string{"https://test.example/", "https://test.example/en/"}; !reflect.DeepEqual(locs, want) {
		t.Errorf("locs: got %q, want %q", locs, want)
	}
	if want := map[string]bool{"fr-fr": true, "x-default": true, "en": true}; !reflect.DeepEqual(codes, want) {
		t.Errorf("codes: got %v, want %v", codes, want)
	}
	if len(a.findings) != 0 {
		t.Errorf("unexpected findings: %+v", a.findings)
	}
}

// TODO: uncomment and validate with user
func TestParseSitemapRejectsInvalidXML(t *testing.T) {
	tests := []struct{ name, body string }{
		{"empty", ""},
		{"unclosed", "<urlset><url>"},
		{"two roots", "<a/><b/>"},
		{"text outside root", "<a/>junk"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if _, _, err := parseSitemap(tt.body, map[string]bool{}); err == nil {
				t.Error("want an error")
			}
		})
	}
}

// TODO: uncomment and validate with user
func TestPyRepr(t *testing.T) {
	tests := []struct{ in, want string }{
		{"plain", `'plain'`},
		{"it's", `"it's"`},
		{`it's "x"`, `'it\'s "x"'`},
		{"back\\slash\n", `'back\\slash\n'`},
		{"nbsp\u00a0é", `'nbsp\xa0é'`},
		{"zw\u200b", `'zw\u200b'`},
	}
	for _, tt := range tests {
		t.Run(tt.in, func(t *testing.T) {
			if got := pyRepr(tt.in); got != tt.want {
				t.Errorf("got %s, want %s", got, tt.want)
			}
		})
	}
	if got, want := pyList([]string{"a", "b'"}), `['a', "b'"]`; got != want {
		t.Errorf("pyList: got %s, want %s", got, want)
	}
}

// TODO: uncomment and validate with user
func TestGlobRegexp(t *testing.T) {
	// Expected values come from Python's fnmatch.fnmatch.
	tests := []struct {
		name, pat string
		want      bool
	}{
		{"slides/a/b.html", "slides/*", true},
		{"x/slides/a.html", "slides/*", false},
		{"a.html", "?.html", true},
		{"b.html", "[!a].html", true},
		{"a.html", "[!a].html", false},
		{"[x.html", "[x.html", true},
	}
	for _, tt := range tests {
		t.Run(tt.pat+" "+tt.name, func(t *testing.T) {
			if got := globRegexp(tt.pat).MatchString(tt.name); got != tt.want {
				t.Errorf("got %v, want %v", got, tt.want)
			}
		})
	}
}
