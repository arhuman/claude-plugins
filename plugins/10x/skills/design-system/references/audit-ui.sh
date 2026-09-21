#!/bin/sh
# audit-ui.sh: mechanical checks for the CSS contract (css-contract.md).
#
# Portable implementation of the audit battery from quality-guards.md, so a
# repo gets a working `make audit-ui` by copying or calling one file. Every
# check is a script decision with an exit code; nothing here is judgment.
#
# Usage:
#   audit-ui.sh tokens          [css-dir]   var(--x) with no --x: definition
#   audit-ui.sh literals        [css-dir]   color literals outside token files (ratcheted)
#   audit-ui.sh breakpoints     [css-dir]   @media value outside the allowlist
#   audit-ui.sh theme-structure [css-dir]   theme scope redeclaring structure
#   audit-ui.sh coupling        [css-dir]   a block file styling another block's selector
#   audit-ui.sh states          [css-dir]   button block missing one of the four states
#   audit-ui.sh bg-color        [css-dir]   theme override changing background without color
#   audit-ui.sh all             [css-dir]   every check above
#   audit-ui.sh baseline        [css-dir]   record the current literals count as the ratchet
#   audit-ui.sh --self-test                 run against built-in fixtures
#
# css-dir defaults to the first existing of: webroot/public/css,
# internal/static/css, web/assets, static/css, assets/css.
#
# Environment:
#   AUDIT_UI_BREAKPOINTS   allowed @media px values, default "640 880 1180"
#   AUDIT_UI_TOKEN_ALLOW   file of extra token names (one --name per line)
#                          tolerated by the tokens check, default
#                          <css-dir>/.audit-token-allow if present
#
# Ratchet: `literals` fails on any occurrence unless <css-dir>/.audit-ui-baseline
# records a count; then only an increase fails. The baseline never goes up to
# green a build; a deliberate addition updates it in the same reviewed commit.
set -u

BREAKPOINTS="${AUDIT_UI_BREAKPOINTS:-640 880 1180}"
COLOR_RE='#[0-9a-fA-F]{3,8}\b|\brgba?\(|\bhsla?\(|\boklch\('
# Structural properties a theme scope must not redeclare (themes own chrome
# and voice only). Anchored so custom properties (--top-x:) never match.
STRUCT_RE='^[[:space:]]*(display|position|float|inset(-[a-z-]+)?|top|right|bottom|left|flex(-[a-z-]+)?|grid(-[a-z-]+)?|(max-|min-)?(width|height)|margin(-[a-z-]+)?|padding(-[a-z-]+)?|gap|overflow(-[xy])?)[[:space:]]*:'
# Every Layout primitive parameters, legitimately set per-instance and often
# only defined by a style="--stack-gap: ..." attribute the CSS never declares.
PARAM_TOKEN_RE='^--(stack|cluster|switcher|sidebar|grid|cover|center|box|frame|flow|gutter)-'

fail=0

find_css_dir() {
  for d in webroot/public/css internal/static/css web/assets static/css assets/css; do
    [ -d "$d" ] && { echo "$d"; return 0; }
  done
  return 1
}

css_files() { # all css under $1
  find "$1" -name '*.css' -not -path '*/node_modules/*' -not -path '*/vendor/*' </dev/null
}

is_token_file() { # $1: path. Files allowed to hold literal values.
  case "$(basename "$1")" in
    tokens.css|global.css|fonts.css) return 0 ;;
  esac
  case "$1" in */themes/*) return 0 ;; esac
  return 1
}

check_tokens() {
  dir=$1; tmp_def=$(mktemp); tmp_use=$(mktemp)
  for f in $(css_files "$dir"); do
    grep -hoE -- '--[a-zA-Z0-9_-]+[[:space:]]*:' "$f" 2>/dev/null | sed 's/[[:space:]]*:$//'
  done | sort -u >"$tmp_def"
  # Only fallback-less usages: var(--x, fallback) is legal with no definition,
  # the author already decided what happens when the token is absent.
  for f in $(css_files "$dir"); do
    grep -hoE 'var\(--[a-zA-Z0-9_-]+[[:space:]]*\)' "$f" 2>/dev/null |
      sed -E 's/^var\(//; s/[[:space:]]*\)$//'
  done | sort -u >"$tmp_use"
  allow="${AUDIT_UI_TOKEN_ALLOW:-$dir/.audit-token-allow}"
  bad=$(comm -23 "$tmp_use" "$tmp_def" | grep -vE "$PARAM_TOKEN_RE" || true)
  if [ -f "$allow" ] && [ -n "$bad" ]; then
    bad=$(echo "$bad" | grep -vxF -f "$allow" || true)
  fi
  rm -f "$tmp_def" "$tmp_use"
  if [ -n "$bad" ]; then
    echo "FAIL tokens: var() references with no definition (silent UA fallback):"
    echo "$bad" | sed 's/^/  /'
    return 1
  fi
  echo "PASS tokens"
}

count_literals() { # $1: css-dir. Prints findings on stdout, count on last line.
  n=0
  for f in $(css_files "$1"); do
    is_token_file "$f" && continue
    hits=$(grep -nE "$COLOR_RE" "$f" 2>/dev/null || true)
    if [ -n "$hits" ]; then
      echo "$hits" | sed "s|^|  $f:|"
      n=$((n + $(echo "$hits" | wc -l)))
    fi
  done
  echo "$n"
}

check_literals() {
  dir=$1
  out=$(count_literals "$dir")
  n=$(echo "$out" | tail -1)
  findings=$(echo "$out" | sed '$d')
  base_file="$dir/.audit-ui-baseline"
  base=0
  [ -f "$base_file" ] && base=$(sed -n 's/^literals=//p' "$base_file")
  if [ "$n" -gt "${base:-0}" ]; then
    echo "FAIL literals: $n color literals outside token files (baseline ${base:-0}):"
    echo "$findings"
    return 1
  fi
  echo "PASS literals ($n, baseline ${base:-0})"
}

write_baseline() {
  dir=$1
  n=$(count_literals "$dir" | tail -1)
  echo "literals=$n" >"$dir/.audit-ui-baseline"
  echo "baseline written: literals=$n ($dir/.audit-ui-baseline)"
}

check_breakpoints() {
  dir=$1
  allowed_re=$(echo "$BREAKPOINTS" | tr ' ' '\n' | sed 's/$/px/' | paste -sd'|' -)
  bad=""
  for f in $(css_files "$dir"); do
    vals=$(grep -hoE '@media[^{]*' "$f" 2>/dev/null | grep -oE '[0-9.]+(px|rem|em|ch)' || true)
    [ -n "$vals" ] || continue
    off=$(echo "$vals" | grep -vxE "$allowed_re" || true)
    [ -n "$off" ] && bad="$bad$f: $(echo "$off" | tr '\n' ' ')\n"
  done
  if [ -n "$bad" ]; then
    echo "FAIL breakpoints: @media values outside allowlist ($BREAKPOINTS px):"
    printf '%b' "$bad" | sed 's/^/  /'
    return 1
  fi
  echo "PASS breakpoints"
}

theme_scope_lines() { # $1: file. Prints lines inside top-level [data-theme...] blocks.
  awk -v struct="$STRUCT_RE" '
    !cap && /\[data-theme[^]]*\]/ { cap=1; d=0 }
    cap {
      line=$0
      o=gsub(/{/,"{",line); c=gsub(/}/,"}",line)
      d += o - c
      print FILENAME ":" NR ":" $0
      if (d <= 0 && (o + c) > 0) cap=0
    }
  ' "$1" </dev/null
}

check_theme_structure() {
  dir=$1; bad=""
  for f in $(css_files "$dir"); do
    case "$f" in
      */themes/*) hits=$(grep -nE "$STRUCT_RE" "$f" | sed "s|^|$f:|" || true) ;;
      *)          hits=$(theme_scope_lines "$f" | grep -E ":[0-9]+:$(echo "$STRUCT_RE" | sed 's/^\^//')" || true) ;;
    esac
    [ -n "$hits" ] && bad="$bad$hits\n"
  done
  if [ -n "$bad" ]; then
    echo "FAIL theme-structure: theme scope redeclares structure (themes own chrome and voice only):"
    printf '%b' "$bad" | sed 's/^/  /'
    return 1
  fi
  echo "PASS theme-structure"
}

check_coupling() {
  dir=$1; bad=""
  [ -d "$dir/blocks" ] || { echo "PASS coupling (no blocks/ dir)"; return 0; }
  for f in "$dir"/blocks/*.css; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .css)
    case "$name" in
      mobile) continue ;;                  # the one cross-cutting file, by contract
      [0-9]*) continue ;;                  # numbered multi-block sections own several blocks
    esac
    # Owned: .name plus its BEM element (__x) and modifier (--x) selectors.
    # .name-other is a different block and stays flagged.
    hits=$(grep -nE '^\.[a-zA-Z]' "$f" | grep -vE "^[0-9]+:\.${name}(__|--|[^a-zA-Z0-9_-]|$)" || true)
    [ -n "$hits" ] && bad="$bad$(echo "$hits" | sed "s|^|$f:|")\n"
  done
  if [ -n "$bad" ]; then
    echo "FAIL coupling: block file styles a selector it does not own (filename = block class):"
    printf '%b' "$bad" | sed 's/^/  /'
    return 1
  fi
  echo "PASS coupling"
}

check_states() {
  dir=$1; bad=""
  for f in $(css_files "$dir"); do
    grep -qE '\.(btn|button)[a-zA-Z0-9_-]*[[:space:]]*[,{:]' "$f" 2>/dev/null || continue
    missing=""
    for s in ':hover' ':focus-visible' ':active' ':disabled'; do
      grep -qF "$s" "$f" || missing="$missing $s"
    done
    [ -n "$missing" ] && bad="$bad$f: missing$missing\n"
  done
  if [ -n "$bad" ]; then
    echo "FAIL states: button block without all four interactive states:"
    printf '%b' "$bad" | sed 's/^/  /'
    return 1
  fi
  echo "PASS states"
}

# Rule blocks in theme scopes that set background/background-color without
# redeclaring color: the base color was tuned for the base background, so the
# required contrast changed with the override (css-contract.md, theme rules).
# Line-based: assumes hand-written CSS with declarations on their own lines.
bg_without_color() { # $1: file, $2: mode ("theme" = every block, else [data-theme] selectors only)
  awk -v mode="$2" '
    function flush() {
      if (inrule) {
        themed = (mode == "theme") || (sel ~ /\[data-theme/)
        if (themed && bg && !col) printf "%s:%d: %s\n", FILENAME, startline, sel
      }
      inrule = 0; bg = 0; col = 0
    }
    # background: and background-color: change the surface; background-image
    # alone does not retune the text color contract and custom properties
    # (--x-background:) are excluded by the preceding-character class.
    function scan(s) {
      if (s ~ /(^|[^-a-zA-Z])background(-color)?[ \t]*:/) bg = 1
      if (s ~ /(^|[^-a-zA-Z])color[ \t]*:/) col = 1
    }
    !inrule {
      if ($0 ~ /{/) {
        sel = selbuf " " $0; sub(/{.*/, "", sel)
        gsub(/^[ \t]+|[ \t]+$/, "", sel); selbuf = ""
        inrule = 1; startline = NR
        rest = $0; sub(/^[^{]*{/, "", rest); scan(rest)
        if ($0 ~ /}/) flush()
      } else if ($0 ~ /[^ \t]/) selbuf = selbuf " " $0
      next
    }
    { scan($0); if ($0 ~ /}/) flush() }
  ' "$1" </dev/null
}

check_bg_color() {
  dir=$1; bad=""
  for f in $(css_files "$dir"); do
    case "$f" in
      */themes/*) hits=$(bg_without_color "$f" theme) ;;
      *)          hits=$(bg_without_color "$f" scoped) ;;
    esac
    [ -n "$hits" ] && bad="$bad$hits\n"
  done
  if [ -n "$bad" ]; then
    echo "FAIL bg-color: theme override changes background without redeclaring color:"
    printf '%b' "$bad" | sed 's/^/  /'
    return 1
  fi
  echo "PASS bg-color"
}

run_all() {
  dir=$1; rc=0
  check_tokens "$dir"          || rc=1
  check_literals "$dir"        || rc=1
  check_breakpoints "$dir"     || rc=1
  check_theme_structure "$dir" || rc=1
  check_coupling "$dir"        || rc=1
  check_states "$dir"          || rc=1
  check_bg_color "$dir"        || rc=1
  return $rc
}

self_test() {
  t=$(mktemp -d); rc=0

  good="$t/good"; mkdir -p "$good/blocks"
  cat >"$good/tokens.css" <<'EOF'
:root { --text-primary: #e8e4d8; --bg-base: rgb(17, 18, 16); --space-s: 1rem; }
[data-theme="dark"] { --bg-base: #000; --text-primary: #fff; }
[data-theme="dark"] .card {
  background-color: var(--bg-base);
  color: var(--text-primary);
}
EOF
  cat >"$good/blocks/card.css" <<'EOF'
.card { color: var(--text-primary); padding: var(--space-s); }
.card__title { color: var(--text-primary); }
.card--compact { color: var(--text-primary); }
@media (max-width: 640px) { .card { padding: var(--space-s); } }
EOF
  cat >"$good/blocks/btn.css" <<'EOF'
.btn { color: var(--text-primary); }
.btn:hover { color: var(--text-primary); }
.btn:focus-visible { outline: var(--focus-ring, auto); }
.btn:active { color: var(--text-primary); }
.btn:disabled { color: var(--text-primary); }
EOF

  bad="$t/bad"; mkdir -p "$bad/blocks" "$bad/themes"
  cat >"$bad/tokens.css" <<'EOF'
:root { --text-primary: #fff; }
[data-theme="dark"] {
  --bg-base: #000;
  position: fixed;
}
EOF
  cat >"$bad/blocks/card.css" <<'EOF'
.card { color: #ff0000; border-color: var(--undefined-token); }
.other-block { color: var(--text-primary); }
@media (max-width: 768px) { .card { color: var(--text-primary); } }
EOF
  cat >"$bad/blocks/btn.css" <<'EOF'
.btn { color: var(--text-primary); }
.btn:hover { color: var(--text-primary); }
EOF
  cat >"$bad/themes/loud.css" <<'EOF'
.card { display: grid; }
.hero {
  background: var(--bg-base);
}
EOF

  for c in tokens literals breakpoints theme-structure coupling states bg-color; do
    if ! sh "$0" "$c" "$good" >/dev/null 2>&1; then
      echo "self-test FAIL: $c rejected the clean fixture"; rc=1
    fi
    if sh "$0" "$c" "$bad" >/dev/null 2>&1; then
      echo "self-test FAIL: $c missed the violation fixture"; rc=1
    fi
  done

  rm -rf "$t"
  [ $rc -eq 0 ] && echo "self-test PASS (7 checks, both fixtures)"
  return $rc
}

cmd="${1:-}"
case "$cmd" in
  --self-test) self_test; exit $? ;;
  tokens|literals|breakpoints|theme-structure|coupling|states|bg-color|all|baseline) ;;
  *) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac

dir="${2:-$(find_css_dir || true)}"
[ -n "$dir" ] && [ -d "$dir" ] || { echo "audit-ui.sh: no css directory found or given" >&2; exit 2; }

case "$cmd" in
  tokens)          check_tokens "$dir" ;;
  literals)        check_literals "$dir" ;;
  breakpoints)     check_breakpoints "$dir" ;;
  theme-structure) check_theme_structure "$dir" ;;
  coupling)        check_coupling "$dir" ;;
  states)          check_states "$dir" ;;
  bg-color)        check_bg_color "$dir" ;;
  baseline)        write_baseline "$dir" ;;
  all)             run_all "$dir" ;;
esac
