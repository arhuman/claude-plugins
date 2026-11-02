package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

// Report sections, in output order.
const (
	onPage      = "On-Page SEO"
	links       = "Links"
	usability   = "Usability"
	performance = "Performance"
	social      = "Social"
	geo         = "GEO"
	technology  = "Technology"
)

var sections = []string{onPage, links, usability, performance, social, geo, technology}

var (
	weakAnchors = setOf("click here", "here", "read more", "more", "link", "ici", "cliquez ici", "lire la suite", "en savoir plus", "suite")
	analytics   = []string{"googletagmanager.com", "google-analytics.com", "gtag(", "matomo", "plausible.io", "umami", "goatcounter", "simpleanalytics", "_paq"}
	socialHosts = []string{"facebook.com", "x.com", "twitter.com", "instagram.com", "linkedin.com", "youtube.com"}
	stopwords   = setOf(strings.Fields(`
a about above after again all also am an and any are as at be because been before being below between both but by can
could did do does doing down during each few for from further had has have having he her here hers him his how i if in
into is it its itself just me more most my no nor not now of off on once only or other our out over own same she should
so some such than that the their them then there these they this those through to too under until up very was we were
what when where which while who whom why will with would you your yours
au aux avec ce ces cet cette dans de des du elle en et eux il ils je la le les leur leurs lui ma mais me meme mes moi mon
ne nos notre nous on ou par pas pour qu que qui sa se ses son sur ta te tes toi ton tu un une vos votre vous est sont
ete etre être avoir parce mieux like still enough time years just much many make made fait faire plus comme tout tous toute toutes aussi donc car ni sans sous entre vers chez peu tres bien
alors encore deja ainsi apres avant quand comment pourquoi cela ceci celui celle ceux celles dont ont peut faut`)...)

	emailRe       = regexp.MustCompile(`[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}`)
	skipContentRe = regexp.MustCompile(`(^|/)404(\.html|/)|/page/\d+`)
	indexRe       = regexp.MustCompile(`(^|/)index\.html$`)
	refreshRe     = regexp.MustCompile(`(?i)http-equiv=["']?refresh`)
	zoomBlockRe   = regexp.MustCompile(`user-scalable\s*=\s*no|maximum-scale\s*=\s*1(\.0)?\b`)
	legacyImgRe   = regexp.MustCompile(`(?i)\.(jpe?g|png|gif)($|\?)`)
	modernImgRe   = regexp.MustCompile(`<picture|\.webp|\.avif`)
	titleWordRe   = regexp.MustCompile(`[\p{L}\p{N}_]{3,}`)
	localeRe      = regexp.MustCompile(`\A[a-z]{2,3}_[A-Z]{2}\z`)
	articleRe     = regexp.MustCompile(`/(post|posts|blog|articles?)/[^/]+/?$`)
	timeRe        = regexp.MustCompile(`<time[^>]+datetime`)
	lazyTriggerRe = regexp.MustCompile(`\b(load|revealed|intersect)\b`)
	articleTypes  = setOf("BlogPosting", "Article", "NewsArticle", "TechArticle")
)

var errNoPages = errors.New("no HTML page found")

// finding is one check result; where is a page URL or "site".
type finding struct {
	Section string `json:"section"`
	Check   string `json:"check"`
	Level   string `json:"level"`
	Message string `json:"message"`
	Fix     string `json:"fix"`
	Where   string `json:"where"`
}

type options struct {
	target   string
	baseURL  string
	maxPages int
	excludes []string
	json     bool
	minLevel string
}

type audit struct {
	site     *site
	opts     options
	findings []finding
	pages    []*page
	boiler   map[string]bool

	thin, shortTitles []string
	unfriendly        map[string]bool
}

func (a *audit) add(section, check, level, message, fix, where string) {
	a.findings = append(a.findings, finding{section, check, level, message, fix, where})
}

func (a *audit) run() error {
	if err := a.loadPages(); err != nil {
		return err
	}
	if len(a.pages) == 0 {
		return errNoPages
	}
	a.unfriendly = map[string]bool{}
	a.boiler = boilerplate(a.pages)
	for _, p := range a.pages {
		a.onPage(p)
		a.links(p)
		a.usability(p)
		a.performance(p)
		a.htmx(p)
		if p.indexable {
			a.social(p)
			a.geo(p)
		}
	}
	a.crossPage()
	a.siteFiles()
	a.stylesheets()
	if a.site.remote {
		a.transport()
	}
	return nil
}

// boilerplate returns the terms present on more than 30% of pages, once the
// site has at least 5 pages; they say nothing about one page's topic.
func boilerplate(pages []*page) map[string]bool {
	boiler := map[string]bool{}
	if len(pages) < 5 {
		return boiler
	}
	df := map[string]int{}
	for _, p := range pages {
		for w := range setOf(p.words...) {
			df[w]++
		}
	}
	for w, n := range df {
		if float64(n) > float64(len(pages))*0.3 {
			boiler[w] = true
		}
	}
	return boiler
}

func (a *audit) loadPages() error {
	if a.site.remote {
		a.crawl()
		return nil
	}
	files := []string{a.opts.target}
	if isDir(a.opts.target) {
		files = nil
		err := filepath.WalkDir(a.opts.target, func(path string, d fs.DirEntry, err error) error {
			if err == nil && !d.IsDir() && strings.HasSuffix(d.Name(), ".html") {
				files = append(files, path)
			}
			return nil
		})
		if err != nil {
			return err
		}
		sort.Strings(files)
	}
	excludes := make([]*regexp.Regexp, len(a.opts.excludes))
	for i, pat := range a.opts.excludes {
		excludes[i] = globRegexp(pat)
	}
	absRoot, _ := filepath.Abs(a.site.root)
	for _, path := range files {
		absPath, _ := filepath.Abs(path)
		rel, err := filepath.Rel(absRoot, absPath)
		if err != nil {
			return err
		}
		rel = filepath.ToSlash(rel)
		if matchesAny(excludes, rel) {
			continue
		}
		src, err := readText(path)
		if err != nil {
			return err
		}
		if runeLen(src) < 2000 && refreshRe.MatchString(runeHead(src, 2000)) {
			continue
		}
		a.pages = append(a.pages, parsePage(a.site.origin+"/"+indexRe.ReplaceAllString(rel, "$1"), src))
	}
	return nil
}

func matchesAny(res []*regexp.Regexp, s string) bool {
	for _, re := range res {
		if re.MatchString(s) {
			return true
		}
	}
	return false
}

func (a *audit) crawl() {
	queue, seen := []string{a.opts.target}, map[string]bool{}
	for len(queue) > 0 && len(a.pages) < a.opts.maxPages {
		url := urlDefrag(queue[0])
		queue = queue[1:]
		if seen[url] {
			continue
		}
		seen[url] = true
		status, headers, body := a.site.fetch(url, false)
		ctype, ok := headers["content-type"]
		if !ok {
			ctype = "html"
		}
		if status != 200 || !strings.Contains(ctype, "html") {
			continue
		}
		p := parsePage(url, body)
		p.headers = headers
		a.pages = append(a.pages, p)
		for _, an := range p.anchors {
			href := urlJoin(url, an.attrs["href"])
			if a.site.isInternal(href) && strings.HasPrefix(href, a.site.origin) {
				queue = append(queue, href)
			}
		}
	}
}

func (a *audit) onPage(p *page) {
	w := p.url
	if !p.doctype {
		a.add(technology, "doctype", "FAIL", "no <!doctype html>", "start every document with <!doctype html>", w)
	}
	if p.charset == "" {
		a.add(technology, "charset", "WARN", "no <meta charset>", "<meta charset=utf-8> first in <head>", w)
	}
	robots := p.metas["robots"] + p.headers["x-robots-tag"]
	p.indexable = !strings.Contains(strings.ToLower(robots), "noindex") && !skipContentRe.MatchString(w)
	if !p.indexable {
		a.add(onPage, "noindex", "INFO", "noindex, 404 or pager page: content checks skipped",
			"confirm each one must stay out of search", w)
		return
	}
	switch n := runeLen(p.title); {
	case p.title == "":
		a.add(onPage, "title", "FAIL", "missing <title>", "unique title per page, 10-70 chars, main keyword first", w)
	case n < 10 || n > 70:
		a.add(onPage, "title-length", "WARN", fmt.Sprintf("title is %d chars: %s", n, pyRepr(p.title)),
			"aim for 50-60 chars, keyword first, site name as suffix", w)
	case n < 30:
		a.shortTitles = append(a.shortTitles, p.title)
	}
	desc := pyStrip(p.metas["description"])
	if n := runeLen(desc); desc == "" {
		a.add(onPage, "meta-description", "FAIL", "missing meta description", "120-160 chars summarising the page", w)
	} else if n < 70 || n > 160 {
		a.add(onPage, "meta-description-length", "WARN", fmt.Sprintf("meta description is %d chars", n),
			"120-160 chars; generate from the page summary, not the site tagline", w)
	}
	a.headingChecks(p)
	if len(p.words) < 500 {
		a.thin = append(a.thin, fmt.Sprintf("%s (%d)", urlSplit(w).path, len(p.words)))
	}
	a.keywordConsistency(p, desc)
	var canon []attrs
	for _, l := range p.links {
		if contains(pyFields(strings.ToLower(l["rel"])), "canonical") {
			canon = append(canon, l)
		}
	}
	if len(canon) != 1 {
		a.add(onPage, "canonical", failIfZero(len(canon)), fmt.Sprintf("%d canonical links", len(canon)),
			"one absolute <link rel=canonical> per page", w)
	} else if !strings.HasPrefix(canon[0]["href"], "http") {
		a.add(onPage, "canonical", "WARN", "canonical href is not absolute", "use an absolute https URL", w)
	}
	var missingAlt []string
	for _, img := range p.imgs {
		if !img.has("alt") {
			src, ok := img["src"]
			if !ok {
				src = "?"
			}
			missingAlt = append(missingAlt, src)
		}
	}
	if len(missingAlt) > 0 {
		a.add(onPage, "img-alt", "FAIL", fmt.Sprintf("%d <img> without alt: %s", len(missingAlt), pyList(head(missingAlt, 3))),
			"descriptive alt; alt=\"\" only for decorative images", w)
	}
	if p.lang == "" {
		a.add(onPage, "lang", "FAIL", "<html> has no lang", "set lang to the page language (fr, en)", w)
	}
	a.hreflang(p)
	p.types = a.jsonldTypes(p)
	if len(p.types) == 0 {
		a.add(onPage, "structured-data", "WARN", "no JSON-LD structured data",
			"WebSite/Organization on home, BlogPosting/Article on posts, BreadcrumbList on deep pages", w)
	}
	for name := range p.metas {
		if strings.HasPrefix(name, "keywords") {
			a.add(onPage, "meta-keywords", "INFO", "meta keywords present", "ignored by search engines; harmless", w)
			break
		}
	}
}

func failIfZero(n int) string {
	if n == 0 {
		return "FAIL"
	}
	return "WARN"
}

func contains(items []string, s string) bool {
	for _, it := range items {
		if it == s {
			return true
		}
	}
	return false
}

func (a *audit) headingChecks(p *page) {
	h1, sub := 0, false
	for _, h := range p.headings {
		if h.level == 1 {
			h1++
		} else {
			sub = true
		}
	}
	if h1 != 1 {
		a.add(onPage, "h1", failIfZero(h1), fmt.Sprintf("%d <h1> on the page", h1), "exactly one <h1> stating the page topic", p.url)
	}
	if !sub {
		a.add(onPage, "headings", "WARN", "no H2-H6 subheadings", "structure content with <h2>/<h3>", p.url)
	}
	prev := 0
	for _, h := range p.headings {
		if prev > 0 && h.level > prev+1 {
			a.add(onPage, "heading-order", "WARN", fmt.Sprintf("h%d followed by h%d (%s)", prev, h.level, pyRepr(runeHead(h.text, 40))),
				"do not skip levels; restyle with CSS instead of picking a smaller tag", p.url)
			break
		}
		prev = h.level
	}
}

func (a *audit) keywordConsistency(p *page, desc string) {
	top := mostCommon(p.words, 5, func(w string) bool { return runeLen(w) > 3 && !stopwords[w] && !a.boiler[w] })
	placed := []string{p.title, desc}
	for _, h := range p.headings {
		if h.level <= 3 {
			placed = append(placed, h.text)
		}
	}
	text := strings.ToLower(strings.Join(placed, " "))
	missing := 0
	for _, t := range top {
		if !strings.Contains(text, t) {
			missing++
		}
	}
	if len(top) > 0 && missing >= 4 {
		a.add(onPage, "keyword-consistency", "INFO", fmt.Sprintf("top body terms %s barely appear in title/description/headings", pyList(top)),
			"use the page's main keywords in title, description and headings", p.url)
	}
}

func (a *audit) hreflang(p *page) {
	var alts []attrs
	for _, l := range p.links {
		if strings.ToLower(l["rel"]) == "alternate" && l["hreflang"] != "" {
			alts = append(alts, l)
		}
	}
	if len(alts) == 0 {
		return
	}
	xDefault, self := false, false
	for _, l := range alts {
		xDefault = xDefault || strings.ToLower(l["hreflang"]) == "x-default"
		self = self || l["href"] == urlDefrag(p.url)
	}
	if !xDefault {
		a.add(onPage, "hreflang", "WARN", "hreflang set without x-default", "add an x-default alternate", p.url)
	}
	if !self {
		a.add(onPage, "hreflang", "INFO", "hreflang set does not list the page itself", "each page lists itself in its alternates", p.url)
	}
}

func (a *audit) jsonldTypes(p *page) []string {
	var types []string
	for _, raw := range p.jsonld {
		var data any
		if err := json.Unmarshal([]byte(raw), &data); err != nil {
			a.add(onPage, "structured-data", "FAIL", "JSON-LD does not parse", "emit JSON with jsonify, never by hand", p.url)
			continue
		}
		var nodes []any
		switch d := data.(type) {
		case []any:
			nodes = d
		case map[string]any:
			nodes = []any{d}
			if g, ok := d["@graph"]; ok {
				nodes, _ = g.([]any)
			}
		}
		for _, n := range nodes {
			node, ok := n.(map[string]any)
			if !ok {
				continue
			}
			switch t := node["@type"].(type) {
			case []any:
				for _, v := range t {
					types = append(types, fmt.Sprint(v))
				}
			case string:
				if t != "" {
					types = append(types, t)
				}
			case nil:
			default:
				if truthy(t) {
					types = append(types, fmt.Sprint(t))
				}
			}
		}
	}
	return types
}

func truthy(v any) bool {
	switch t := v.(type) {
	case bool:
		return t
	case float64:
		return t != 0
	case map[string]any:
		return len(t) > 0
	}
	return v != nil
}

func (a *audit) links(p *page) {
	w := p.url
	internal, external, nofollow := 0, 0, 0
	weak, empty, broken := map[string]bool{}, map[string]bool{}, map[string]bool{}
	for _, an := range p.anchors {
		href := pyStrip(an.attrs["href"])
		if href == "" || hasAnyPrefix(href, "#", "mailto:", "tel:", "javascript:") {
			if strings.HasPrefix(href, "javascript:") || (href == "" && an.attrs["hx-get"] == "") {
				a.add(links, "crawlable-links", "WARN", fmt.Sprintf("<a> without real href (%s)", pyRepr(runeHead(pyStrip(an.text), 30))),
					"every navigation link needs an href crawlers can follow", w)
			}
			continue
		}
		if strings.Contains(an.attrs["rel"], "nofollow") {
			nofollow++
		}
		full := urlJoin(w, href)
		if a.site.isInternal(full) {
			internal++
			path := urlSplit(full).path
			if strings.Contains(path, "_") || path != strings.ToLower(path) || runeLen(full) > 115 {
				a.unfriendly[path] = true
			}
			if !a.site.remote && a.site.urlToFile(full) == "" {
				broken[path] = true
			}
		} else {
			external++
		}
		text := strings.ToLower(strings.Join(pyFields(an.text), " "))
		if weakAnchors[text] {
			weak[text] = true
		} else if text == "" && an.attrs["aria-label"] == "" && an.attrs["title"] == "" {
			empty[href] = true
		}
	}
	if len(broken) > 0 {
		a.add(links, "broken-links", "FAIL", fmt.Sprintf("%d internal link(s) to missing files: %s", len(broken), pyList(head(sortedKeys(broken), 3))),
			"fix the link or the target slug", w)
	}
	if len(weak) > 0 {
		a.add(links, "anchor-text", "INFO", "generic anchor text: "+pyList(sortedKeys(weak)), "describe the target in the link text", w)
	}
	if len(empty) > 0 {
		a.add(links, "anchor-text", "WARN", fmt.Sprintf("%d link(s) with no accessible text: %s", len(empty), pyList(head(sortedKeys(empty), 3))),
			"add visible text or aria-label (icon links)", w)
	}
	if internal == 0 {
		a.add(links, "internal-links", "WARN", "no internal links", "link to related pages", w)
	}
	if total := internal + external; total > 0 && float64(nofollow)/float64(total) > 0.5 {
		a.add(links, "nofollow", "WARN", fmt.Sprintf("%d of %d links are nofollow", nofollow, total), "reserve nofollow for untrusted links", w)
	}
}

func hasAnyPrefix(s string, prefixes ...string) bool {
	for _, pre := range prefixes {
		if strings.HasPrefix(s, pre) {
			return true
		}
	}
	return false
}

func (a *audit) usability(p *page) {
	w := p.url
	vp := p.metas["viewport"]
	if !strings.Contains(vp, "width=device-width") {
		a.add(usability, "viewport", "FAIL", "no responsive viewport meta", `<meta name=viewport content="width=device-width,initial-scale=1">`, w)
	}
	if zoomBlockRe.MatchString(vp) {
		a.add(usability, "viewport", "WARN", "viewport blocks zoom", "drop user-scalable=no and maximum-scale", w)
	}
	mails := map[string]bool{}
	for _, an := range p.anchors {
		if href := an.attrs["href"]; strings.HasPrefix(href, "mailto:") {
			addr, _, _ := strings.Cut(href[len("mailto:"):], "?")
			mails[addr] = true
		}
	}
	for _, m := range emailRe.FindAllString(strings.Join(p.bodyText, " "), -1) {
		mails[m] = true
	}
	if len(mails) > 0 {
		a.add(usability, "email-privacy", "WARN", "plain email address in HTML: "+pyList(head(sortedKeys(mails), 2)),
			"contact form, or assemble the address client side (cloaked mailto)", w)
	}
	if p.iframes > 0 {
		a.add(usability, "iframes", "INFO", fmt.Sprintf("%d iframe(s)", p.iframes), "keep indexable content out of iframes", w)
	}
	if p.embeds > 0 {
		a.add(usability, "flash", "FAIL", fmt.Sprintf("%d <embed>/<object>", p.embeds), "replace plugin content with HTML5", w)
	}
	for _, l := range p.links {
		if strings.Contains(strings.ToLower(l["rel"]), "icon") {
			return
		}
	}
	a.add(usability, "favicon", "WARN", "no <link rel=icon>", "declare favicon (svg + png 180 apple-touch-icon)", w)
}

func (a *audit) performance(p *page) {
	w := p.url
	if p.size > 100_000 {
		a.add(performance, "html-size", "WARN", fmt.Sprintf("HTML is %d KB", p.size/1024), "keep the document under 100 KB", w)
	}
	var blocking []string
	resources := len(p.imgs)
	for _, s := range p.scripts {
		src := s.attrs["src"]
		if src != "" {
			resources++
		}
		if s.inHead && src != "" && !s.attrs.has("async") && !s.attrs.has("defer") && s.attrs["type"] != "module" {
			blocking = append(blocking, src)
		}
	}
	if len(blocking) > 0 {
		a.add(performance, "render-blocking-js", "WARN", "blocking scripts in <head>: "+pyList(head(blocking, 3)), "add defer (or async for independent scripts)", w)
	}
	for _, l := range p.links {
		href, stylesheet := l["href"], strings.Contains(l["rel"], "stylesheet")
		if stylesheet {
			resources++
		}
		if stylesheet && strings.Contains(href, "fonts.googleapis.com") && !strings.Contains(href, "display=") {
			a.add(performance, "font-display", "WARN", "Google Fonts without display=swap: "+href,
				"append &display=swap or self-host with font-display: swap", w)
		}
	}
	if resources > 50 {
		a.add(performance, "requests", "WARN", fmt.Sprintf("%d scripts/stylesheets/images", resources), "bundle CSS/JS, lazy-load images", w)
	}
	a.imageChecks(p)
	if p.inlineStyles > 10 {
		a.add(performance, "inline-styles", "WARN", fmt.Sprintf("%d inline style attributes", p.inlineStyles), "move styles to CSS classes", w)
	}
	if len(p.deprecated) > 0 {
		counts := make([]string, len(p.deprecated))
		for i, d := range p.deprecated {
			counts[i] = fmt.Sprintf("%s: %d", pyRepr(d.tag), d.n)
		}
		a.add(performance, "deprecated-html", "WARN", "deprecated tags: {"+strings.Join(counts, ", ")+"}", "replace with semantic HTML + CSS", w)
	}
	if a.site.remote && p.headers != nil {
		switch p.headers["content-encoding"] {
		case "gzip", "br", "zstd", "deflate":
		default:
			a.add(performance, "compression", "FAIL", "HTML served uncompressed", "enable gzip/brotli on the server or CDN", w)
		}
	}
}

func (a *audit) imageChecks(p *page) {
	w := p.url
	legacy, lazy := 0, false
	for _, img := range p.imgs {
		if legacyImgRe.MatchString(img["src"]) {
			legacy++
		}
		lazy = lazy || img["loading"] == "lazy"
	}
	for _, img := range p.imgs {
		if (img["width"] == "" || img["height"] == "") && !strings.Contains(img["style"], "aspect-ratio") {
			a.add(performance, "img-dimensions", "WARN", "<img> without width/height: "+img["src"], "set width and height to avoid layout shift (CLS)", w)
			break
		}
	}
	if legacy > 0 && !modernImgRe.MatchString(p.raw) {
		a.add(performance, "image-format", "INFO", fmt.Sprintf("%d JPEG/PNG/GIF images", legacy), "serve WebP/AVIF with srcset", w)
	}
	if len(p.imgs) > 3 && !lazy {
		a.add(performance, "lazy-images", "INFO", "no image uses loading=lazy", "lazy-load images below the fold", w)
	}
}

func (a *audit) social(p *page) {
	w := p.url
	for _, prop := range []string{"og:title", "og:description", "og:image", "og:url", "og:type"} {
		if p.props[prop] == "" {
			a.add(social, "open-graph", "WARN", "missing "+prop, "emit full Open Graph set from page data", w)
		}
	}
	ogt, ogd := p.props["og:title"], p.props["og:description"]
	if ogt != "" && p.title != "" {
		og, title := setOf(titleWordRe.FindAllString(strings.ToLower(ogt), -1)...), setOf(titleWordRe.FindAllString(strings.ToLower(p.title), -1)...)
		if len(og) > 0 && len(title) > 0 && !intersects(og, title) {
			a.add(social, "og-consistency", "WARN", fmt.Sprintf("og:title %s unrelated to <title> %s", pyRepr(ogt), pyRepr(p.title)),
				"derive og:title from the same source as <title>", w)
		}
	}
	if runeLen(ogd) > 200 || strings.Contains(ogd, "\n") {
		a.add(social, "og-description", "WARN", fmt.Sprintf("og:description is %d chars or multi-line", runeLen(ogd)),
			"reuse the meta description (single line, <= 200 chars)", w)
	}
	if img := p.props["og:image"]; img != "" && !strings.HasPrefix(img, "http") {
		a.add(social, "og-image", "FAIL", "og:image is not absolute", "absolute https URL, 1200x630", w)
	}
	for _, l := range p.links {
		if contains(pyFields(l["rel"]), "canonical") {
			if ogURL := p.props["og:url"]; l["href"] != "" && ogURL != "" && ogURL != l["href"] {
				a.add(social, "og-url", "INFO", "og:url differs from canonical", "use the canonical URL", w)
			}
			break
		}
	}
	if loc := p.props["og:locale"]; loc != "" && !localeRe.MatchString(loc) {
		a.add(social, "og-locale", "WARN", fmt.Sprintf("og:locale %s not in ll_CC form", pyRepr(loc)), "e.g. fr_FR, en_US", w)
	}
	if p.metas["twitter:card"] == "" {
		a.add(social, "twitter-card", "WARN", "no twitter:card", "twitter:card=summary_large_image (falls back to og: for the rest)", w)
	}
}

func intersects(a, b map[string]bool) bool {
	for k := range a {
		if b[k] {
			return true
		}
	}
	return false
}

func (a *audit) geo(p *page) {
	if !articleRe.MatchString(urlSplit(p.url).path) {
		return
	}
	if p.props["article:published_time"] == "" && !strings.Contains(p.raw, "datePublished") && !timeRe.MatchString(p.raw) {
		a.add(geo, "pubdate", "WARN", "article without machine-readable publication date",
			"datePublished in JSON-LD and article:published_time", p.url)
	}
	for _, t := range p.types {
		if articleTypes[t] {
			return
		}
	}
	a.add(geo, "article-schema", "WARN", "article page without Article/BlogPosting JSON-LD",
		"BlogPosting with headline, datePublished, dateModified, author, image", p.url)
}

func (a *audit) htmx(p *page) {
	for _, h := range p.htmx {
		trigger, ok := h.hx["hx-trigger"]
		if !ok {
			trigger = h.hx["data-hx-trigger"]
		}
		get := h.hx["hx-get"] != "" || h.hx["data-hx-get"] != ""
		if get && lazyTriggerRe.MatchString(trigger) {
			a.add(links, "htmx-lazy-content", "WARN", fmt.Sprintf("<%s> loads content on %s: crawlers will not see it", h.tag, pyRepr(trigger)),
				"render indexable content server side; lazy-load only secondary widgets", p.url)
		}
		if h.tag == "a" && h.href == "" && get {
			hxGet := "None"
			if v, ok := h.hx["hx-get"]; ok {
				hxGet = pyRepr(v)
			}
			a.add(links, "htmx-href", "FAIL", fmt.Sprintf("<a hx-get=%s> without href", hxGet),
				"keep a real href to the full-page URL; hx-get or hx-boost enhances it", p.url)
		}
	}
}
