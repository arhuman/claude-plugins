# Go version package

The other half of the ldflags contract in `makefile-go.md`. A binary has three
build paths and only two of them apply `-ldflags`:

| Path | Stamps ldflags | Version source |
| ---- | -------------- | -------------- |
| `make build` | yes | `git describe --tags --always --dirty` |
| goreleaser (tag) | yes | `v{{ .Version }}` |
| `go install <module>/cmd/<tool>@latest` | **no** | `debug.ReadBuildInfo()` only |

A package that reads the linker alone therefore reports `dev (unknown, unknown)`
for a tagged release installed the way most users install it, and the Makefile
probe still passes because the Makefile does stamp. The fallback below is what
closes that path.

## Rules

- Name the three variables exactly as the Makefile's `VERSION_PKG` expects
  (`Version`, `GitCommit`, `BuildDate`); the linker sets a package-level variable
  by qualified name, and only one initialised to a constant string.
- Fall back to `debug.ReadBuildInfo()` when a value is still the placeholder:
  `info.Main.Version` for a module install, `vcs.revision` and `vcs.time` for a
  working-tree build. `"(devel)"` says no more than `dev` does, so treat it as
  absent.
- Never print a placeholder. Drop the parenthetical instead: `mytool v1.4.0`
  beats `mytool v1.4.0 (unknown, unknown)`, which reads like a broken build.
- Invent nothing. VCS settings exist only for a working-tree build; a module
  install has no commit and no date, and the honest output omits them.
- Keep one resolved value behind `--version`, the SARIF/JSON tool version, the
  user agent, and anything else that reports a version, so they cannot drift.
- Keep the `v` prefix identical across the three paths. goreleaser's `.Version`
  strips it, so the config must put it back (`v{{ .Version }}`); `git describe`
  and the module version both keep it.

## Template

`internal/version/version.go` (drop the package wrapper if `VERSION_PKG` is
`main`, and keep the variable names):

```go
// Package version reports which build of this binary is running.
package version

import "runtime/debug"

// Stamped at link time via -ldflags -X: see the Makefile's VERSION_PKG and
// .goreleaser.yaml. Exported because the linker addresses a variable by its
// qualified name, and can only set one initialised to a constant string.
var (
	Version   = "dev"
	GitCommit = "unknown"
	BuildDate = "unknown"
)

// The values the three variables hold when nothing stamped them.
const (
	devVersion  = "dev"
	unknownMeta = "unknown"
)

// Build is what this binary reports about itself, resolved once at startup.
var Build = resolve(Metadata{Version, GitCommit, BuildDate}, readBuildInfo())

func readBuildInfo() *debug.BuildInfo {
	info, ok := debug.ReadBuildInfo()
	if !ok {
		return nil
	}
	return info
}

// Metadata is the version, commit and build date this binary reports. Commit
// and date are empty when the build carries nothing to fill them, and the
// rendered line then omits them rather than printing a placeholder.
type Metadata struct {
	Version string
	Commit  string
	Date    string
}

// resolve derives the reported metadata from the linker-stamped values, falling
// back to the build info the toolchain embeds. Split from the package-level
// variable so the fallbacks can be tested without relinking the test binary.
//
// info may be nil, which happens only for a binary built without module
// information at all.
func resolve(stamped Metadata, info *debug.BuildInfo) Metadata {
	m := stamped
	if m.Commit == unknownMeta {
		m.Commit = ""
	}
	if m.Date == unknownMeta {
		m.Date = ""
	}
	if info == nil {
		return m
	}
	if m.Version == devVersion && info.Main.Version != "" && info.Main.Version != "(devel)" {
		m.Version = info.Main.Version
	}
	var revision string
	var modified bool
	for _, s := range info.Settings {
		switch s.Key {
		case "vcs.revision":
			revision = s.Value
		case "vcs.time":
			if m.Date == "" {
				m.Date = s.Value
			}
		case "vcs.modified":
			modified = s.Value == "true"
		}
	}
	// Read after the loop, not inside it: the settings carry no ordering
	// guarantee, and the dirty marker would be lost if it came second.
	if m.Commit == "" && revision != "" {
		m.Commit = shortRevision(revision)
		if modified {
			m.Commit += "-dirty"
		}
	}
	return m
}

// shortRevision abbreviates a commit hash to the width the Makefile and
// goreleaser stamp, so the three build paths print the same shape.
func shortRevision(rev string) string {
	const short = 7
	if len(rev) <= short {
		return rev
	}
	return rev[:short]
}

// String renders the metadata as it appears after the program name.
func (m Metadata) String() string {
	switch {
	case m.Commit == "" && m.Date == "":
		return m.Version
	case m.Date == "":
		return m.Version + " (" + m.Commit + ")"
	case m.Commit == "":
		return m.Version + " (" + m.Date + ")"
	default:
		return m.Version + " (" + m.Commit + ", " + m.Date + ")"
	}
}
```

The CLI then prints one line and exits, with no other version literal anywhere:

```go
if *showVersion {
	fmt.Fprintf(stdout, "mytool %s\n", version.Build)
	return 0
}
```

## Verifying it

Unit-testing `resolve` covers the branches, but not that the module path really
carries a version. Prove that end to end once, with a local file proxy:

```sh
MOD=github.com/USER/PROJECT; V=v0.9.9
mkdir -p /tmp/proxy/$MOD/@v /tmp/stage/$MOD@$V
git archive HEAD | tar -x -C /tmp/stage/$MOD@$V
(cd /tmp/stage && zip -qr /tmp/proxy/$MOD/@v/$V.zip $MOD@$V)
cp /tmp/stage/$MOD@$V/go.mod /tmp/proxy/$MOD/@v/$V.mod
printf '{"Version":"%s"}\n' $V > /tmp/proxy/$MOD/@v/$V.info
GOSUMDB=off GOPROXY=file:///tmp/proxy GOBIN=/tmp/gobin go install $MOD/cmd/PROJECT@$V
/tmp/gobin/PROJECT --version   # want: PROJECT v0.9.9
```

The zip's single top-level directory must be `<module>@<version>`, and the major
version has to match the module path (`v0`/`v1` without a `/vN` suffix). Delete
the fake version from `$GOPATH/pkg/mod/cache/download` afterwards.
