#!/bin/sh
# Promotion check: print every module whose packages the main module imports
# directly (code and tests) while go.mod does not declare it as a direct
# requirement. Only direct imports count: a module reached through a
# dependency's own imports is legitimately indirect, so walking
# `go list -deps` would flag the whole transitive closure.
#
# Exit 0 with no output is a pass; exit 1 prints the offending modules; exit 2
# means go failed, so an error can never read as a pass. go.mod is only read:
# -mod=readonly stops go list from rewriting a stale `// indirect` marker.
#
# Usage, from the module root: promotion-check.sh [go flags, e.g. -tags embed]
set -u

imports=$(go list -mod=readonly "$@" -f '{{join .Imports "\n"}}
{{join .TestImports "\n"}}
{{join .XTestImports "\n"}}' ./...) || exit 2
imports=$(printf '%s\n' "$imports" | sed '/^$/d; /^C$/d' | sort -u)
[ -n "$imports" ] || exit 0

# One argument per import path; import paths never contain whitespace.
# shellcheck disable=SC2086
used=$(go list -mod=readonly "$@" -f '{{with .Module}}{{if not .Main}}{{.Path}}{{end}}{{end}}' $imports) || exit 2
used=$(printf '%s\n' "$used" | sed '/^$/d' | sort -u)
[ -n "$used" ] || exit 0

mod=$(go mod edit -print) || exit 2
direct=$(mktemp) || exit 2
trap 'rm -f "$direct"' EXIT
printf '%s\n' "$mod" | awk '
  /^require \(/ { blk = 1; next }
  blk && /^\)/ { blk = 0; next }
  blk { if ($0 !~ /\/\/ indirect/) print $1; next }
  /^require / { if ($0 !~ /\/\/ indirect/) print $2 }
' | sort -u > "$direct"

missing=$(printf '%s\n' "$used" | comm -23 - "$direct")
[ -z "$missing" ] && exit 0
printf '%s\n' "$missing"
exit 1
