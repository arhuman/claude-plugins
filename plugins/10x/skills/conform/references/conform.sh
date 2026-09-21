#!/bin/sh
# conform.sh: check a repo against the 10x engineering standard.
#
# This is a portable, dependency-free (POSIX sh + grep + test) VIEW of the
# authoritative manifest ../../_shared/references/standard.yml. Regenerate it from
# the manifest after editing standard.yml so the two stay in sync.
# It is global: one copy lives here in the plugin and runs against any repo via a
# target-dir argument. It is not copied into audited repos. CI that wants to gate
# fetches this file at job time (see the conform skill's "Enforce in CI").
#
# Usage: sh conform.sh [target-dir]        (default: .)
# Env:   CONFORM_WARN=1     report only, always exit 0 (nightly annotation mode)
#        CONFORM_STRICT=1   also fail on P1 (default: fail on P0 only)
#        CONFORM_PROFILE=   audience profile: private | internal | public
#                           (default: read `10x-profile:` from CLAUDE.md, else public)
set -u

STANDARD_VERSION="1.13"
TARGET="${1:-.}"
cd "$TARGET" 2>/dev/null || { echo "conform: cannot enter $TARGET" >&2; exit 2; }

# ---- audience profile ----
# applies_to answers "what kind of artifact is this"; the profile answers the
# orthogonal "who consumes it". Only governance, release and supply-chain checks
# vary by it. Default is the strictest, so an undeclared repo never quietly loses
# checks: weakening the standard has to be written down in the repo.
PROFILE="${CONFORM_PROFILE:-}"
if [ -z "$PROFILE" ]; then
  PROFILE=$(grep -hsoE '10x-profile:[[:space:]]*[a-z]+' CLAUDE.md AGENTS.md 2>/dev/null \
            | head -1 | sed 's/.*10x-profile:[[:space:]]*//')
fi
case "${PROFILE:-}" in
  private|internal|public) ;;
  '') PROFILE=public ;;
  *) echo "conform: unknown profile '$PROFILE', using public" >&2; PROFILE=public ;;
esac

# ---- repo type detection -> space-delimited TYPES ----
TYPES=""
add_type() { TYPES="$TYPES $1"; }
if [ -f go.mod ] || [ -f go.work ]; then
  add_type go
  if ls cmd/*/*.go >/dev/null 2>&1 || grep -rqsE '^package main' cmd 2>/dev/null; then
    if ls Dockerfile* >/dev/null 2>&1 || ls docker-compose*.yml >/dev/null 2>&1; then
      add_type go-service
    else
      add_type go-cli
    fi
  else
    add_type go-lib
  fi
fi
if [ -f pyproject.toml ] || [ -f setup.py ]; then
  add_type python
  if ls Dockerfile* >/dev/null 2>&1 || ls docker-compose*.yml >/dev/null 2>&1; then
    add_type python-service
  elif grep -qsE '^\[project\.scripts\]' pyproject.toml || grep -qsE 'console_scripts' setup.py setup.cfg 2>/dev/null; then
    add_type python-cli
  else
    add_type python-lib
  fi
fi
{ [ -f buf.yaml ] || [ -f buf.gen.yaml ]; } && add_type proto
# A server-rendered UI is not always at the root: Go projects keep templates
# under internal/, which the root-only test missed entirely.
{ [ -d templates ] || [ -d webroot ] || ls ./*.templ >/dev/null 2>&1 \
  || find . -maxdepth 4 -type d \( -name templates -o -name webroot \) \
       -not -path './.git/*' -not -path './node_modules/*' -not -path './vendor/*' \
       2>/dev/null | grep -q . ; } && add_type web-app
[ -z "$TYPES" ] && TYPES=" generic"

has_type() { for t in $TYPES; do [ "$t" = "$1" ] && return 0; done; return 1; }
applies() {
  case "$1" in *all*) return 0 ;; esac
  oifs=$IFS; IFS=,
  for a in $1; do IFS=$oifs; has_type "$a" && return 0; IFS=,; done
  IFS=$oifs; return 1
}

# Effective severity for the active profile. $1 = baseline, $2 = overrides
# (`private=NA,internal=P2`, empty when the check does not vary). NA drops it.
eff_sev() {
  [ -z "$2" ] && { printf '%s' "$1"; return; }
  oifs=$IFS; IFS=,
  for kv in $2; do
    IFS=$oifs
    case "$kv" in "$PROFILE"=*) printf '%s' "${kv#*=}"; return ;; esac
    IFS=,
  done
  IFS=$oifs
  printf '%s' "$1"
}

# ---- checks: id | applies_to(comma) | severity | profiles(comma k=v) | probe ----
# (last field keeps embedded | from grep alternations verbatim, which is fine)
# ---- ui probes ----
# Defined as functions because the CHECKS table is pipe-separated and these
# probes need alternation and pipelines.
_ui_find_css() {
  find . -name '*.css' -not -name tokens.css \
    -not -path './.git/*' -not -path './node_modules/*' -not -path './vendor/*' 2>/dev/null
}
_ui_layers() {
  find . -type d -name blocks -not -path './.git/*' -not -path './node_modules/*' \
    -not -path './vendor/*' 2>/dev/null | grep -q . && return 0
  find . -name tokens.css -not -path './.git/*' -not -path './node_modules/*' \
    2>/dev/null | grep -q .
}
_ui_no_color_literals() {
  hits=$(_ui_find_css | xargs -r grep -lE '#[0-9a-fA-F]{3,8}\b' 2>/dev/null | head -1)
  [ -z "$hits" ]
}

CHECKS='
ci.audit|go|P0||grep -rqsE "make audit" .github/workflows
version.stamp|go-service,go-cli|P0||grep -qsE "\-X .*\.Version=" Makefile && grep -rqs ReadBuildInfo --include=*.go .
docker.nonroot|go-service,web-app|P0||grep -qsE "^USER +[A-Za-z1-9]" Dockerfile* && ! grep -qsE "^USER +root" Dockerfile*
compose.security_headers|go-service,web-app|P0||grep -qsE "headers\.stsSeconds" docker-compose.prod.yml || grep -rqsE "Strict-Transport-Security" --include=*.go .
compose.ports_configurable|go-service,web-app|P1||! cat docker-compose.yml docker-compose.local.yml docker-compose.prod.yml 2>/dev/null | grep -qE "[0-9]{2,5}:[0-9]{2,5}"
compose.proxy_routing|go-service,web-app|P1||! grep -qsE "traefik\.enable=true" docker-compose.prod.yml || { grep -qsE "traefik\.docker\.network" docker-compose.prod.yml && grep -qsE "external: *true" docker-compose.prod.yml ; }
compose.apex_domain|go-service,web-app|P2||! grep -qsE "Host\(" docker-compose.prod.yml || grep -qsE "_DOMAIN" docker-compose.prod.yml
compose.traefik_apex|go-service,web-app|P1||grep -qsE "^up:" Makefile && grep -qsE "docker-compose\.prod\.yml" Makefile && grep -qsE "traefik\.enable=true" docker-compose.prod.yml && grep -qsE "Host\([^)]*APEX_DOMAIN" docker-compose.prod.yml
lint.config|go|P0||ls .golangci.y*ml >/dev/null 2>&1
coverage.gate|go|P1||grep -qsE "COVER_MIN" Makefile
makefile.test_split|go-service,go-lib,web-app,cli|P1||! test -f Makefile || { grep -qsE "^test:" Makefile && grep -qsE "^fulltest:" Makefile; }
makefile.local_run|go-service,web-app|P1||grep -qsE "^local:" Makefile && grep -qsE "^up:" Makefile && grep -qsE "^down:" Makefile
makefile.local_port|go-service,web-app|P2||grep -qsE "^[A-Za-z_]*PORT[A-Za-z_]* *\?=" Makefile && grep -qsE "echo.*(localhost|127\.0\.0\.1)" Makefile
makefile.prod_preflight|go-service,web-app|P1||{ ! grep -qsE "Host\(" docker-compose.prod.yml && ! { grep -qsE "^[[:space:]]*ports:" docker-compose.prod.yml && grep -qsE "(PASSWORD|SECRET|TOKEN|_KEY)" docker-compose.yml docker-compose.prod.yml ; } ; } || { grep -qsE "^up:.*preflight" Makefile && grep -qsE "^preflight:" Makefile ; }
docker.healthcheck|go-service,web-app|P1||grep -qsE "HEALTHCHECK" Dockerfile* || grep -qsE "healthcheck:" docker-compose*.yml
release.goreleaser|go-service,go-cli|P1|private=P2,internal=P1,public=P1|ls .goreleaser.y*ml >/dev/null 2>&1
release.workflow|go-service,go-cli,go-lib,python-service,python-cli,python-lib|P1|private=P2,internal=P1,public=P1|test -f .github/workflows/release.yml
release.python_build|python-service,python-cli,python-lib|P1|private=P2,internal=P1,public=P1|grep -qsE "^\[build-system\]" pyproject.toml
release.script|go-service,go-cli,go-lib,python-service,python-cli,python-lib|P2||test -f scripts/release.sh && { [ ! -f Makefile ] || grep -qsE "scripts/release\.sh" Makefile ; }
governance.security_md|all|P1|private=NA,internal=P2,public=P1|test -f SECURITY.md
governance.contributing|all|P1|private=NA,internal=P2,public=P1|test -f CONTRIBUTING.md
governance.dependabot|all|P1||test -f .github/dependabot.yml
governance.codeowners|all|P2|private=NA,internal=P1,public=P2|test -f CODEOWNERS || test -f .github/CODEOWNERS
governance.changelog_root|all|P2|private=P2,internal=P2,public=P1|test -f CHANGELOG.md
ui.cube_layers|web-app|P2||_ui_layers
ui.color_literals|web-app|P2||_ui_no_color_literals
ui.contract|web-app|P2||test -f docs/ux.md || test -f .claude/project/ux.md
commit.ci_check|all|P2|private=P2,internal=P1,public=P1|grep -rqsE "commitlint" .github/workflows
supply_chain.sign_sbom|go-service,go-cli|P2|private=NA,internal=P2,public=P1|grep -qsE "sboms:|signs:" .goreleaser.y*ml
supply_chain.scan|go-service,web-app|P2|private=P2,internal=P1,public=P1|grep -rqsE "trivy|grype|codeql" .github/workflows
'

tmp=$(mktemp)
printf '%s\n' "$CHECKS" > "$tmp"

pass=0; fail=0; skip=0; p0fail=0; p1fail=0; offprofile=0
printf '%-28s %-4s %-6s\n' "CHECK" "SEV" "STATUS"
printf '%-28s %-4s %-6s\n' "----------------------------" "----" "------"
while IFS='|' read -r id ap sev povr probe; do
  [ -z "$id" ] && continue
  esev=$(eff_sev "$sev" "$povr")
  disp=$esev
  [ "$esev" = NA ] && disp="-"
  if ! applies "$ap"; then
    status="N/A"; skip=$((skip + 1))
  elif [ "$esev" = NA ]; then
    # Not applicable to this audience, not a pass. Counted separately so a
    # profile can never inflate the headline by turning gaps into passes.
    status="N/A"; skip=$((skip + 1)); offprofile=$((offprofile + 1))
  elif eval "$probe" >/dev/null 2>&1; then
    status="PASS"; pass=$((pass + 1))
  else
    status="FAIL"; fail=$((fail + 1))
    [ "$esev" = P0 ] && p0fail=$((p0fail + 1))
    [ "$esev" = P1 ] && p1fail=$((p1fail + 1))
  fi
  printf '%-28s %-4s %-6s\n' "$id" "$disp" "$status"
done < "$tmp"
rm -f "$tmp"

echo
echo "standard v$STANDARD_VERSION | profile:$PROFILE | types:$TYPES"
echo "pass=$pass fail=$fail n/a=$skip   (P0 fails=$p0fail, P1 fails=$p1fail)"
[ "$offprofile" -gt 0 ] && echo "note: $offprofile check(s) dropped by profile '$PROFILE'; re-run with CONFORM_PROFILE=public to see them"

[ "${CONFORM_WARN:-0}" = 1 ] && exit 0
[ "$p0fail" -gt 0 ] && exit 1
[ "${CONFORM_STRICT:-0}" = 1 ] && [ "$p1fail" -gt 0 ] && exit 1
exit 0
