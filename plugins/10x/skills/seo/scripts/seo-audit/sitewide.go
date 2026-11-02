package main

import (
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"
)

var (
	disallowAllRe = regexp.MustCompile(`(?im)^disallow:\s*/\s*$`)
	sitemapLineRe = regexp.MustCompile(`(?im)^sitemap:\s*(\S+)`)
	cssRuleRe     = regexp.MustCompile(`([^{}]+)\{([^{}]*)\}`)
	fontSizeRe    = regexp.MustCompile(`font-size\s*:\s*([\d.]+)(px|rem|em)\b`)
	baseSelRe     = regexp.MustCompile(`\A\s*(html|body)\s*\z`)
	maxAgeRe      = regexp.MustCompile(`max-age=(\d+)`)
	versionRe     = regexp.MustCompile(`/\d`)
)

// crossPage reports the per-page facts aggregated site-wide: thin content,
// unfriendly URLs, short and duplicate titles, analytics, social profiles.
func (a *audit) crossPage() {
	if len(a.thin) > 0 {
		a.add(onPage, "content-amount", "WARN", fmt.Sprintf("%d page(s) under 500 words: %s", len(a.thin), pyList(head(a.thin, 5))),
			"500+ words on pages meant to rank; merge or noindex thin pages", "site")
	}
	if len(a.unfriendly) > 0 {
		a.add(links, "friendly-urls", "INFO", fmt.Sprintf("%d URL(s) with underscores, capitals or > 115 chars: %s", len(a.unfriendly), pyList(head(sortedKeys(a.unfriendly), 4))),
			"lowercase hyphenated slugs for new pages; renaming live URLs needs 301 redirects", "site")
	}
	if len(a.shortTitles) > 0 {
		a.add(onPage, "title-length", "INFO", fmt.Sprintf("%d title(s) under 30 chars: %s", len(a.shortTitles), pyList(head(a.shortTitles, 4))),
			"aim for 50-60 chars, add the topic, not only the brand", "site")
	}
	a.duplicates("title", func(p *page) string { return p.title })
	a.duplicates("meta description", func(p *page) string { return p.metas["description"] })
	if !a.anyPageContains(analytics) {
		a.add(technology, "analytics", "INFO", "no analytics detected", "add privacy-friendly analytics if traffic matters", "site")
	}
	if !a.linksToSocial() {
		a.add(social, "social-profiles", "INFO", "no link to social profiles", "link profiles and list them in JSON-LD sameAs", "site")
	}
}

func (a *audit) duplicates(label string, value func(*page) string) {
	var order []string
	groups := map[string][]string{}
	for _, p := range a.pages {
		v := value(p)
		if v == "" || !p.indexable {
			continue
		}
		if _, seen := groups[v]; !seen {
			order = append(order, v)
		}
		groups[v] = append(groups[v], p.url)
	}
	for _, v := range order {
		if urls := groups[v]; len(urls) > 1 {
			a.add(onPage, "duplicate-"+strings.ReplaceAll(label, " ", "-"), "WARN",
				fmt.Sprintf("%d pages share %s %s: %s", len(urls), label, pyRepr(runeHead(v, 50)), pyList(head(urls, 3))),
				"make each "+label+" unique", "site")
		}
	}
}

func (a *audit) anyPageContains(needles []string) bool {
	for _, p := range a.pages {
		for _, n := range needles {
			if strings.Contains(p.raw, n) {
				return true
			}
		}
	}
	return false
}

func (a *audit) linksToSocial() bool {
	for _, p := range a.pages {
		for _, an := range p.anchors {
			for _, h := range socialHosts {
				if strings.Contains(an.attrs["href"], h) {
					return true
				}
			}
		}
	}
	return false
}

func (a *audit) siteFiles() {
	o := a.site.origin
	status, _, robots := a.site.fetch(o+"/robots.txt", false)
	if status != 200 {
		a.add(onPage, "robots-txt", "FAIL", "no robots.txt", "serve robots.txt with a Sitemap: line", "site")
	} else {
		if disallowAllRe.MatchString(robots) {
			a.add(onPage, "robots-txt", "FAIL", "robots.txt disallows /", "allow crawling of public pages", "site")
		}
		if !strings.Contains(strings.ToLower(robots), "sitemap:") {
			a.add(onPage, "robots-txt", "WARN", "robots.txt has no Sitemap: line", "add Sitemap: absolute URL", "site")
		}
	}
	var sitemaps []string
	for _, m := range sitemapLineRe.FindAllStringSubmatch(robots, -1) {
		sitemaps = append(sitemaps, m[1])
	}
	if len(sitemaps) == 0 {
		sitemaps = []string{o + "/sitemap.xml"}
	}
	locs, codes := a.readSitemaps(sitemaps, 0)
	if len(locs) == 0 {
		a.add(onPage, "sitemap", "FAIL", "no readable XML sitemap", "generate sitemap.xml listing canonical URLs", "site")
	}
	a.hreflangConsistency(codes)
	if status, _, _ := a.site.fetch(o+"/llms.txt", a.site.remote); status != 200 {
		a.add(geo, "llms-txt", "INFO", "no /llms.txt", "publish llms.txt: site summary + key page links in Markdown", "site")
	}
	status, _, _ = a.site.fetch(o+"/this-page-should-not-exist-10x", a.site.remote)
	if a.site.remote && status == 200 {
		a.add(technology, "soft-404", "FAIL", "unknown URL returns 200", "return 404 status for missing pages", "site")
	}
	if !a.site.remote && !isFile(pyJoin(a.site.root, "404.html")) {
		a.add(technology, "404-page", "INFO", "no 404.html", "add a helpful 404 page", "site")
	}
}

func (a *audit) hreflangConsistency(sitemapCodes map[string]bool) {
	pageCodes := map[string]bool{}
	for _, p := range a.pages {
		for _, l := range p.links {
			if code := strings.ToLower(l["hreflang"]); code != "" && code != "x-default" {
				pageCodes[code] = true
			}
		}
	}
	if len(sitemapCodes) == 0 || len(pageCodes) == 0 {
		return
	}
	same := len(pageCodes) == len(sitemapCodes)-boolToInt(sitemapCodes["x-default"])
	for code := range pageCodes {
		same = same && sitemapCodes[code]
	}
	if !same {
		a.add(onPage, "hreflang-consistency", "WARN",
			fmt.Sprintf("hreflang codes differ: pages %s vs sitemap %s", pyList(sortedKeys(pageCodes)), pyList(sortedKeys(sitemapCodes))),
			"emit the same language codes in <head> and sitemap", "site")
	}
}

func boolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

// readSitemaps returns the <loc> URLs and hreflang codes of up to 10
// sitemaps, following one level of sitemap index.
func (a *audit) readSitemaps(urls []string, depth int) ([]string, map[string]bool) {
	var locs []string
	codes := map[string]bool{}
	for _, url := range head(urls, 10) {
		status, _, body := a.site.fetch(url, false)
		if status != 200 {
			continue
		}
		root, found, err := parseSitemap(body, codes)
		if err != nil {
			a.add(onPage, "sitemap", "FAIL", url+" is not valid XML", "fix the sitemap template", "site")
			continue
		}
		locs = append(locs, found...)
		if strings.HasSuffix(root, "sitemapindex") && depth == 0 {
			sub, subCodes := a.readSitemaps(locs, 1)
			locs = sub
			for c := range subCodes {
				codes[c] = true
			}
		}
	}
	return locs, codes
}

var errNoRoot = errors.New("no root element")

// parseSitemap returns the root element name and every <loc> text, adding
// the hreflang codes of <link> elements to codes. Like a strict XML parser it
// rejects documents without a single root element.
func parseSitemap(body string, codes map[string]bool) (string, []string, error) {
	d := xml.NewDecoder(strings.NewReader(strings.TrimPrefix(body, "\ufeff")))
	d.CharsetReader = func(_ string, r io.Reader) (io.Reader, error) { return r, nil }
	var (
		root, loc    string
		locs         []string
		depth, locAt int
		closed       bool
	)
	flush := func() {
		if locAt > 0 && loc != "" {
			locs = append(locs, pyStrip(loc))
		}
		locAt, loc = 0, ""
	}
	for {
		tok, err := d.Token()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return "", nil, err
		}
		switch t := tok.(type) {
		case xml.StartElement:
			if closed {
				return "", nil, errors.New("junk after document element")
			}
			if depth == 0 {
				root = t.Name.Local
			}
			if locAt > 0 && depth == locAt {
				flush()
			}
			depth++
			switch t.Name.Local {
			case "loc":
				locAt = depth
			case "link":
				for _, at := range t.Attr {
					if at.Name.Space == "" && at.Name.Local == "hreflang" && at.Value != "" {
						codes[strings.ToLower(at.Value)] = true
					}
				}
			}
		case xml.EndElement:
			if depth == locAt {
				flush()
			}
			depth--
			closed = depth == 0
		case xml.CharData:
			if depth == 0 && strings.TrimSpace(string(t)) != "" {
				return "", nil, errors.New("text outside the root element")
			}
			if locAt > 0 && depth == locAt {
				loc += string(t)
			}
		}
	}
	if root == "" {
		return "", nil, errNoRoot
	}
	return root, locs, nil
}

func (a *audit) stylesheets() {
	seen := map[string]bool{}
	for _, p := range head(a.pages, 20) {
		for _, l := range p.links {
			href := urlJoin(p.url, l["href"])
			if !strings.Contains(l["rel"], "stylesheet") || seen[href] || !a.site.isInternal(href) {
				continue
			}
			seen[href] = true
			status, headers, css := a.site.fetch(href, false)
			if status != 200 {
				continue
			}
			path := urlSplit(href).path
			a.cssChecks(path, css)
			if a.site.remote {
				a.cacheCheck(headers, path)
			}
		}
	}
}

func (a *audit) cssChecks(path, css string) {
	if n := runeLen(css); n > 2048 && float64(strings.Count(css, "\n")) > float64(n)/120 {
		a.add(performance, "minify", "WARN", path+" not minified", "minify CSS/JS in the build", "site")
	}
	var small []string
	for _, rule := range cssRuleRe.FindAllStringSubmatch(css, -1) {
		sel, m := rule[1], fontSizeRe.FindStringSubmatch(rule[2])
		if m == nil {
			continue
		}
		size, err := strconv.ParseFloat(m[1], 64)
		if err != nil {
			continue
		}
		if (m[2] == "px" && size < 12) || (m[2] != "px" && size < 0.75) {
			small = append(small, fmt.Sprintf("%s %s%s", runeHead(pyStrip(sel), 40), m[1], m[2]))
		}
		if baseSelRe.MatchString(sel) && m[2] == "px" && size < 16 {
			a.add(usability, "font-size", "WARN", fmt.Sprintf("%s: base font %spx", path, m[1]),
				"base font >= 16px on mobile (override in project CSS)", "site")
		}
	}
	if len(small) > 0 {
		a.add(usability, "legible-fonts", "WARN", fmt.Sprintf("%s: font-size below 12px: %s", path, pyList(head(small, 4))),
			"min 12px for any text, 14px+ for metadata", "site")
	}
}

func (a *audit) cacheCheck(headers map[string]string, path string) {
	cc := headers["cache-control"]
	m := maxAgeRe.FindStringSubmatch(cc)
	if m != nil {
		if n, err := strconv.Atoi(m[1]); err != nil || n >= 604800 {
			return
		}
	}
	a.add(performance, "cache", "WARN", fmt.Sprintf("%s: cache-control %s", path, pyRepr(cc)),
		"static assets: max-age=31536000, immutable when fingerprinted", "site")
}

func (a *audit) transport() {
	if !strings.HasPrefix(a.site.origin, "https://") {
		a.add(technology, "ssl", "FAIL", "site is not served over HTTPS", "serve over HTTPS", "site")
		return
	}
	code, loc := a.plainHTTP()
	if code != 0 && !((code == 301 || code == 308) && strings.HasPrefix(loc, "https://")) {
		a.add(technology, "https-redirect", "FAIL", fmt.Sprintf("http:// answers %d %s", code, loc), "301 redirect all http traffic to https", "site")
	}
	h := a.pages[0].headers
	if _, ok := h["strict-transport-security"]; !ok {
		a.add(technology, "hsts", "INFO", "no Strict-Transport-Security header", "add HSTS (max-age=31536000)", "site")
	}
	if _, powered := h["x-powered-by"]; powered || versionRe.MatchString(h["server"]) {
		a.add(technology, "server-signature", "INFO", "server version exposed", "hide Server/X-Powered-By versions", "site")
	}
	htmx := false
	for _, p := range a.pages {
		htmx = htmx || len(p.htmx) > 0
	}
	if htmx && !strings.Contains(strings.ToLower(h["vary"]), "hx-request") {
		a.add(technology, "htmx-vary", "WARN", "HTMX page without Vary: HX-Request",
			"send Vary: HX-Request so caches never serve a partial as a full page", "site")
	}
}

// plainHTTP sends HEAD http://host/ without following redirects and returns
// the status and Location; status 0 means a network error.
func (a *audit) plainHTTP() (int, string) {
	req, err := http.NewRequest(http.MethodHead, "http://"+a.site.host+"/", nil)
	if err != nil {
		return 0, ""
	}
	req.Header.Set("User-Agent", userAgent)
	client := &http.Client{
		Timeout:       15 * time.Second,
		Transport:     a.site.client.Transport,
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}
	resp, err := client.Do(req)
	if err != nil {
		return 0, ""
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		return resp.StatusCode, ""
	}
	return resp.StatusCode, resp.Header.Get("Location")
}
