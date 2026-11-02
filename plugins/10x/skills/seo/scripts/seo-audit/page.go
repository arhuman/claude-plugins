package main

import (
	"regexp"
	"strings"

	"golang.org/x/net/html"
)

var (
	deprecatedTags = setOf("font", "center", "marquee", "frame", "frameset", "big", "strike", "tt", "blink", "applet", "basefont")
	voidTags       = setOf("meta", "link", "img", "br", "hr", "input", "source", "area", "base", "col", "wbr")
	hiddenText     = setOf("script", "style", "noscript", "template")
	wordRe         = regexp.MustCompile(`[\p{L}\p{Nl}\p{No}]{2,}`)
)

func setOf(items ...string) map[string]bool {
	m := make(map[string]bool, len(items))
	for _, s := range items {
		m[s] = true
	}
	return m
}

// attrs holds one tag's attributes; a repeated attribute keeps its first
// value, as the HTML tokenizer (and browsers) do.
type attrs map[string]string

func (a attrs) has(key string) bool {
	_, ok := a[key]
	return ok
}

type heading struct {
	level int
	text  string
}

type script struct {
	attrs  attrs
	inHead bool
}

type anchor struct {
	attrs attrs
	text  string
}

type htmxTag struct {
	tag  string
	hx   attrs
	href string
}

type tagCount struct {
	tag string
	n   int
}

// page is one parsed document: the fields the checks read, nothing else.
type page struct {
	url     string
	size    int
	raw     string
	headers map[string]string

	doctype       bool
	lang, charset string
	title         string
	hasTitle      bool
	metas, props  map[string]string
	links         []attrs
	scripts       []script
	jsonld        []string
	headings      []heading
	imgs          []attrs
	anchors       []*anchor
	iframes       int
	embeds        int
	inlineStyles  int
	deprecated    []tagCount
	htmx          []htmxTag
	bodyText      []string
	words         []string

	indexable bool
	types     []string
}

// pageParser walks tokens the way Python's event-based HTMLParser did: an
// open-tag stack, a single text capture (title, heading or JSON-LD) and the
// current anchor. Mirroring the events, not a DOM, keeps findings identical.
type pageParser struct {
	p       *page
	stack   []string
	capture string
	buf     []string
	inHead  bool
	anchor  *anchor
}

func parsePage(url, src string) *page {
	p := &page{url: url, size: len(src), raw: src, metas: map[string]string{}, props: map[string]string{}}
	ps := &pageParser{p: p}
	z := html.NewTokenizer(strings.NewReader(src))
	for {
		switch z.Next() {
		case html.ErrorToken:
			p.words = wordRe.FindAllString(strings.ToLower(strings.Join(p.bodyText, " ")), -1)
			return p
		case html.DoctypeToken:
			if strings.HasPrefix(strings.ToLower(string(z.Raw())), "<!doctype html") {
				p.doctype = true
			}
		case html.StartTagToken:
			tok := z.Token()
			// Python parses noscript content as markup (scripting=False).
			if tok.Data == "noscript" {
				z.NextIsNotRawText()
			}
			ps.start(tok.Data, attrsOf(tok))
		case html.SelfClosingTagToken:
			z.NextIsNotRawText()
			tok := z.Token()
			ps.start(tok.Data, attrsOf(tok))
			ps.end(tok.Data)
		case html.EndTagToken:
			ps.end(z.Token().Data)
		case html.TextToken:
			ps.text(string(z.Text()))
		}
	}
}

func attrsOf(tok html.Token) attrs {
	a := make(attrs, len(tok.Attr))
	for _, at := range tok.Attr {
		a[at.Key] = at.Val
	}
	return a
}

func (ps *pageParser) start(tag string, a attrs) {
	p := ps.p
	if a.has("style") {
		p.inlineStyles++
	}
	hx := attrs{}
	for k, v := range a {
		if strings.HasPrefix(k, "hx-") || strings.HasPrefix(k, "data-hx-") {
			hx[k] = v
		}
	}
	if len(hx) > 0 {
		p.htmx = append(p.htmx, htmxTag{tag: tag, hx: hx, href: a["href"]})
	}
	if deprecatedTags[tag] {
		p.countDeprecated(tag)
	}
	switch {
	case tag == "html":
		p.lang = a["lang"]
	case tag == "head":
		ps.inHead = true
	case tag == "body":
		ps.inHead = false
	case tag == "meta":
		p.readMeta(a)
	case tag == "link":
		p.links = append(p.links, a)
	case tag == "script":
		p.scripts = append(p.scripts, script{attrs: a, inHead: ps.inHead})
		if a["type"] == "application/ld+json" {
			ps.begin("jsonld")
		}
	case tag == "title" && !p.hasTitle:
		ps.begin("title")
	case headingLevel(tag) > 0:
		ps.begin(tag)
	case tag == "img":
		p.imgs = append(p.imgs, a)
		if ps.anchor != nil {
			ps.anchor.text += " " + a["alt"]
		}
	case tag == "a":
		ps.anchor = &anchor{attrs: a}
		p.anchors = append(p.anchors, ps.anchor)
	case tag == "iframe":
		p.iframes++
	case tag == "embed" || tag == "object":
		p.embeds++
	}
	if !voidTags[tag] {
		ps.stack = append(ps.stack, tag)
	}
}

func (p *page) readMeta(a attrs) {
	if a.has("charset") {
		p.charset = a["charset"]
	} else if content := a["content"]; strings.ToLower(a["http-equiv"]) == "content-type" && strings.Contains(content, "charset=") {
		p.charset = content[strings.LastIndex(content, "charset=")+len("charset="):]
	}
	if a.has("name") {
		p.metas[strings.ToLower(a["name"])] = a["content"]
	}
	if a.has("property") {
		p.props[strings.ToLower(a["property"])] = a["content"]
	}
}

func (p *page) countDeprecated(tag string) {
	for i := range p.deprecated {
		if p.deprecated[i].tag == tag {
			p.deprecated[i].n++
			return
		}
	}
	p.deprecated = append(p.deprecated, tagCount{tag: tag, n: 1})
}

func headingLevel(tag string) int {
	if len(tag) == 2 && tag[0] == 'h' && tag[1] >= '1' && tag[1] <= '6' {
		return int(tag[1] - '0')
	}
	return 0
}

func (ps *pageParser) begin(what string) {
	ps.capture, ps.buf = what, nil
}

func (ps *pageParser) end(tag string) {
	for len(ps.stack) > 0 {
		last := ps.stack[len(ps.stack)-1]
		ps.stack = ps.stack[:len(ps.stack)-1]
		if last == tag {
			break
		}
	}
	if tag == "a" {
		ps.anchor = nil
	}
	if ps.capture == "" || (tag != ps.capture && (ps.capture != "jsonld" || tag != "script")) {
		return
	}
	text := strings.Join(ps.buf, "")
	switch ps.capture {
	case "title":
		ps.p.title, ps.p.hasTitle = strings.Join(pyFields(text), " "), true
	case "jsonld":
		ps.p.jsonld = append(ps.p.jsonld, text)
	default:
		ps.p.headings = append(ps.p.headings, heading{level: headingLevel(ps.capture), text: strings.Join(pyFields(text), " ")})
	}
	ps.capture = ""
}

func (ps *pageParser) text(data string) {
	if ps.capture != "" {
		ps.buf = append(ps.buf, data)
	}
	if n := len(ps.stack); n > 0 && hiddenText[ps.stack[n-1]] {
		return
	}
	if ps.anchor != nil {
		ps.anchor.text += data
	}
	if !ps.inHead {
		ps.p.bodyText = append(ps.p.bodyText, data)
	}
}
