package main

import (
	"bytes"
	"compress/gzip"
	"compress/zlib"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

const userAgent = "Mozilla/5.0 (compatible; 10x-seo-audit/1.0)"

// site reads pages and site files from a directory or over HTTP.
type site struct {
	remote bool
	origin string
	host   string
	root   string
	client *http.Client
}

func newSite(target, baseURL string, client *http.Client) *site {
	s := &site{remote: isURL(target), client: client}
	if s.remote {
		u := urlSplit(target)
		s.origin = u.scheme + "://" + u.netloc
	} else {
		s.root = target
		if !isDir(target) {
			abs, _ := filepath.Abs(target)
			s.root = filepath.Dir(abs)
		}
		if baseURL == "" {
			baseURL = "https://example.invalid"
		}
		s.origin = strings.TrimRight(baseURL, "/")
	}
	s.host = urlSplit(s.origin).netloc
	return s
}

func isURL(s string) bool {
	return strings.HasPrefix(s, "http://") || strings.HasPrefix(s, "https://")
}

func isDir(path string) bool {
	fi, err := os.Stat(path)
	return err == nil && fi.IsDir()
}

func isFile(path string) bool {
	fi, err := os.Stat(path)
	return err == nil && fi.Mode().IsRegular()
}

// pyJoin joins like os.path.join: no cleaning, so "dir/" + "" stays "dir/".
func pyJoin(dir, name string) string {
	if strings.HasPrefix(name, "/") {
		return name
	}
	if dir == "" || strings.HasSuffix(dir, "/") {
		return dir + name
	}
	return dir + "/" + name
}

// readText reads a file as Python's text mode did: invalid UTF-8 replaced,
// CRLF and CR normalized to LF.
func readText(path string) (string, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	s := strings.ReplaceAll(strings.ToValidUTF8(string(b), "\uFFFD"), "\r\n", "\n")
	return strings.ReplaceAll(s, "\r", "\n"), nil
}

// fetch returns the status, lowercased headers and body of url; status 0
// means a network error. In directory mode it maps the URL to a file.
func (s *site) fetch(url string, headOnly bool) (int, map[string]string, string) {
	if !s.remote {
		path := s.urlToFile(url)
		if path == "" {
			return 404, map[string]string{}, ""
		}
		text, err := readText(path)
		if err != nil || headOnly {
			return 200, map[string]string{}, ""
		}
		return 200, map[string]string{}, text
	}
	method := http.MethodGet
	if headOnly {
		method = http.MethodHead
	}
	req, err := http.NewRequest(method, url, nil)
	if err != nil {
		return 0, map[string]string{}, ""
	}
	req.Header.Set("User-Agent", userAgent)
	// An explicit Accept-Encoding keeps Content-Encoding visible for the compression check.
	req.Header.Set("Accept-Encoding", "gzip")
	resp, err := s.client.Do(req)
	if err != nil {
		return 0, map[string]string{}, ""
	}
	defer resp.Body.Close()
	headers := map[string]string{}
	for k, vs := range resp.Header {
		headers[strings.ToLower(k)] = vs[len(vs)-1]
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 || headOnly {
		return resp.StatusCode, headers, ""
	}
	body, err := readBody(resp)
	if err != nil {
		return 0, map[string]string{}, ""
	}
	return resp.StatusCode, headers, strings.ToValidUTF8(string(body), "\uFFFD")
}

func readBody(resp *http.Response) ([]byte, error) {
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	var r io.ReadCloser
	switch resp.Header.Get("Content-Encoding") {
	case "gzip":
		r, err = gzip.NewReader(bytes.NewReader(body))
	case "deflate":
		r, err = zlib.NewReader(bytes.NewReader(body))
	default:
		return body, nil
	}
	if err != nil {
		return nil, err
	}
	defer r.Close()
	return io.ReadAll(r)
}

// urlToFile maps a site URL to the file a static server would send, or ""
// when it is off-site or missing.
func (s *site) urlToFile(url string) string {
	u := urlSplit(urlJoin(s.origin+"/", url))
	if u.netloc != "" && u.netloc != s.host {
		return ""
	}
	base := pyJoin(s.root, strings.TrimLeft(unquote(u.path), "/"))
	for _, cand := range []string{base, base + ".html", pyJoin(base, "index.html")} {
		if isFile(cand) {
			return cand
		}
	}
	return ""
}

func (s *site) isInternal(href string) bool {
	u := urlSplit(href)
	return (u.scheme == "" || u.scheme == "http" || u.scheme == "https") && (u.netloc == "" || u.netloc == s.host)
}

// urlParts mirrors urllib.parse.urlsplit, keeping "absent" apart from "empty"
// for the components urljoin treats differently.
type urlParts struct {
	scheme, netloc, path, query, fragment string
	hasNetloc, hasQuery, hasFragment      bool
}

const schemeChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+-."

var (
	usesRelative = setOf("", "ftp", "http", "gopher", "nntp", "imap", "wais", "file", "https", "shttp", "mms",
		"prospero", "rtsp", "rtsps", "rtspu", "sftp", "svn", "svn+ssh", "ws", "wss")
	usesNetloc = setOf("", "ftp", "http", "gopher", "nntp", "telnet", "imap", "wais", "file", "mms", "https", "shttp",
		"snews", "prospero", "rtsp", "rtsps", "rtspu", "rsync", "svn", "svn+ssh", "sftp", "nfs", "git", "git+ssh", "ws", "wss", "itms-services")
	unsafeURLBytes = strings.NewReplacer("\t", "", "\r", "", "\n", "")
)

func urlSplit(raw string) urlParts {
	s := unsafeURLBytes.Replace(strings.TrimLeftFunc(raw, func(r rune) bool { return r <= ' ' }))
	var u urlParts
	if i := strings.IndexByte(s, ':'); i > 0 && isASCIILetter(s[0]) && strings.Trim(s[:i], schemeChars) == "" {
		u.scheme, s = strings.ToLower(s[:i]), s[i+1:]
	}
	if strings.HasPrefix(s, "//") {
		end := len(s)
		if i := strings.IndexAny(s[2:], "/?#"); i >= 0 {
			end = i + 2
		}
		u.netloc, u.hasNetloc, s = s[2:end], true, s[end:]
	}
	if before, after, ok := strings.Cut(s, "#"); ok {
		s, u.fragment, u.hasFragment = before, after, true
	}
	if before, after, ok := strings.Cut(s, "?"); ok {
		s, u.query, u.hasQuery = before, after, true
	}
	u.path = s
	return u
}

func isASCIILetter(c byte) bool { return ('a' <= c && c <= 'z') || ('A' <= c && c <= 'Z') }

func (u urlParts) String() string {
	s := u.path
	if u.hasNetloc {
		if s != "" && s[0] != '/' {
			s = "/" + s
		}
		s = "//" + u.netloc + s
	} else if strings.HasPrefix(s, "//") {
		s = "//" + s
	}
	if u.scheme != "" {
		s = u.scheme + ":" + s
	}
	if u.hasQuery {
		s += "?" + u.query
	}
	if u.hasFragment {
		s += "#" + u.fragment
	}
	return s
}

// urlJoin mirrors urllib.parse.urljoin, which (unlike net/url) keeps the
// reference's raw encoding and never fails.
func urlJoin(base, ref string) string {
	if base == "" {
		return ref
	}
	if ref == "" {
		return base
	}
	b, u := urlSplit(base), urlSplit(ref)
	if u.scheme == "" {
		u.scheme = b.scheme
	}
	if u.scheme != b.scheme || (u.scheme != "" && !usesRelative[u.scheme]) {
		return ref
	}
	if u.scheme == "" || usesNetloc[u.scheme] {
		if u.netloc != "" {
			return u.String()
		}
		u.netloc, u.hasNetloc = b.netloc, b.hasNetloc
	}
	if u.path == "" {
		u.path = b.path
		if !u.hasQuery {
			u.query, u.hasQuery = b.query, b.hasQuery
			if !u.hasFragment {
				u.fragment, u.hasFragment = b.fragment, b.hasFragment
			}
		}
		return u.String()
	}
	var segs []string
	if strings.HasPrefix(u.path, "/") {
		segs = strings.Split(u.path, "/")
	} else {
		baseParts := strings.Split(b.path, "/")
		if baseParts[len(baseParts)-1] != "" {
			baseParts = baseParts[:len(baseParts)-1]
		}
		segs = append(baseParts, strings.Split(u.path, "/")...)
		if len(segs) > 2 {
			mid := []string{segs[0]}
			for _, seg := range segs[1 : len(segs)-1] {
				if seg != "" {
					mid = append(mid, seg)
				}
			}
			segs = append(mid, segs[len(segs)-1])
		}
	}
	var resolved []string
	for _, seg := range segs {
		switch seg {
		case "..":
			if len(resolved) > 0 {
				resolved = resolved[:len(resolved)-1]
			}
		case ".":
		default:
			resolved = append(resolved, seg)
		}
	}
	if last := segs[len(segs)-1]; last == "." || last == ".." {
		resolved = append(resolved, "")
	}
	u.path = strings.Join(resolved, "/")
	if u.path == "" {
		u.path = "/"
	}
	return u.String()
}

func urlDefrag(s string) string {
	if !strings.Contains(s, "#") {
		return s
	}
	u := urlSplit(s)
	u.fragment, u.hasFragment = "", false
	return u.String()
}

// unquote decodes %XX escapes leniently, like urllib.parse.unquote.
func unquote(s string) string {
	if !strings.Contains(s, "%") {
		return s
	}
	var b []byte
	for i := 0; i < len(s); i++ {
		if s[i] == '%' && i+2 < len(s) && isHex(s[i+1]) && isHex(s[i+2]) {
			b = append(b, unhex(s[i+1])<<4|unhex(s[i+2]))
			i += 2
			continue
		}
		b = append(b, s[i])
	}
	return strings.ToValidUTF8(string(b), "\uFFFD")
}

func isHex(c byte) bool {
	return ('0' <= c && c <= '9') || ('a' <= c && c <= 'f') || ('A' <= c && c <= 'F')
}

func unhex(c byte) byte {
	switch {
	case c >= 'a':
		return c - 'a' + 10
	case c >= 'A':
		return c - 'A' + 10
	}
	return c - '0'
}
