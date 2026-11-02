---
name: seo
description: 'Audits and fixes a website''s SEO: static HTML, server-rendered HTML/HTMX (Go templates) and Hugo sites. Runs the bundled auditor on built output or a live URL (title, description, headings, keywords, canonical, hreflang, sitemap/robots, structured data, links, mobile usability, performance, Open Graph/Twitter, llms.txt, HTTPS) and fixes each finding at its source. Use when asked to audit, check or improve SEO, meta or social tags, or to act on an SEO report (SEOptimer, Lighthouse SEO). Not for visual design scoring: use `design-system`; for HTMX mechanics use `lang-html`.'
---
# 10x SEO

Audit, fix at the source, re-audit. A finding is fixed only when the auditor no longer reports it on freshly built output.

## Workflow

1. **Detect the stack.** Hugo: `hugo.toml`/`config.toml`/`config/_default/` plus `layouts/` or `themes/`. SSR/HTMX: Go `html/template` files, `hx-*` attributes, HTTP handlers. Static: plain `.html` files.
2. **Produce the output to audit.** Hugo: `hugo --gc --minify -d <scratch>/site` (never audit or edit the committed `public/`). SSR: run the server and audit its URL. Static: the directory itself.
3. **Build the auditor once** (Go 1.26+; `scripts/seo-audit` is its own module, so `go run` from elsewhere fails): `go build -C <this skill dir>/scripts/seo-audit -o <scratch>/seo-audit .`. Then, from the project:
   `<scratch>/seo-audit [-base-url URL] [-exclude 'slides/*'] [-max-pages N] [-json] [-min-level WARN] <dir|file|url>`.
   Pass `-base-url` with a directory so canonical, sitemap and hreflang resolve. Exclude vendored HTML (reveal.js decks, demos). Exit 1 means at least one FAIL.
4. **Run the rendered mobile checks** the static auditor cannot make (SEOptimer's Usability grade): Playwright `browser_resize` 375x812, then `browser_evaluate` with the function in `scripts/mobile-usability.js`. Pass: small text under 40%, no crowded tap target, no horizontal overflow.
5. **Fix each finding at its source** (tables below). Generated HTML is never the fix location.
6. **Rebuild and re-run** steps 3-4. Report what was fixed, what is a justified WARN, and what code cannot fix.

## Fix locations

| Finding | Hugo | SSR/HTMX | Static |
|---|---|---|---|
| title, description, og:*, twitter:*, canonical, hreflang, JSON-LD | `layouts/partials/` head partial (override the theme's by copying it into project `layouts/`), page front matter `description` | base layout template, per-handler page data struct | each `<head>` |
| headings, alt, img width/height | content Markdown, render hooks `layouts/_default/_markup/render-image.html`, widget partials | templates | markup |
| fonts, small text, tap targets | project CSS listed in `customCSS`/assets, never `themes/` | stylesheet | stylesheet |
| robots.txt, sitemap, llms.txt | `enableRobotsTXT` + `layouts/robots.txt`, `layouts/_default/sitemap.xml`, `static/llms.txt` | handlers or embedded static files | root files |
| cache, compression, HSTS, redirects | `static/_headers` and `static/_redirects` (Cloudflare Pages, Netlify), else the server/CDN | middleware | server/CDN |

Edit `themes/` only when the theme belongs to the project (not a submodule or vendored upstream); otherwise override.

## Stack rules

- **One source per fact.** `<title>`, `og:title` and JSON-LD `headline` come from the same field; `og:description` reuses the meta description (one line, at most 200 chars). The home page uses the site title and description, never the content of `_index.md` or the about page.
- **Language codes agree.** `<html lang>`, `hreflang` in `<head>`, the sitemap `xhtml:link`, and `og:locale` (`fr_FR` form) derive from one per-language config value; include `x-default`.
- **Hugo:** set `twitter_cards`/`opengraph` params or emit the tags in the head partial; Google Fonts URLs get `&display=swap` (or self-host); fingerprint CSS/JS (`resources.Fingerprint`) before setting `max-age=31536000, immutable` in `_headers`; give taxonomy and pager pages `noindex` or unique titles per language.
- **SSR/HTMX:** crawlers run no JavaScript. Every navigable view has a full-page URL rendering a complete `<head>`; return the partial only when `HX-Request` is set and send `Vary: HX-Request`. Links keep a real `href` (`hx-get`/`hx-boost` enhance it); `hx-push-url` targets must render in full on direct load. Never load indexable content with `hx-trigger="load|revealed|intersect"`. Canonical points to the full-page URL; partial endpoints send `X-Robots-Tag: noindex`.
- **Email privacy:** replace plain `mailto:` with a contact form or an address assembled client side; keep a `<noscript>` fallback that is not a raw address.

## Not fixable in code

Backlinks and domain authority, Google Business Profile and local listings, SPF/DMARC (`dig TXT`), CrUX field data, social follower counts. List them as recommendations; never report them fixed.

## Done when

The auditor shows no FAIL on rebuilt output, each remaining WARN has a stated reason, the mobile checks pass, and the site build still succeeds.
