#!/bin/sh
# verify-ux.sh - check docs/ux.md against UX contract v1.
# Usage: verify-ux.sh [ux-file]   (default: docs/ux.md)
# Exits 0 if conformant or absent, 1 on any violation.
# Reads only tracked files, so it is safe to wire into CI.
set -eu

UX="${1:-docs/ux.md}"
fail=0
warn() { printf 'UX: %s\n' "$1" >&2; fail=1; }

[ -f "$UX" ] || { echo "UX: no $UX (no UI contract yet), ok"; exit 0; }

# --- frontmatter: ui_paths ---------------------------------------------------
# Extract the value of ui_paths from the leading --- block.
ui_paths=$(awk '
  NR==1 && $0!="---" { exit }
  NR==1 { infm=1; next }
  infm && $0=="---" { exit }
  infm && /^ui_paths:/ { sub(/^ui_paths:[ \t]*/,""); print; exit }
' "$UX")

[ -n "$ui_paths" ] || warn "frontmatter has no ui_paths: the loop gate cannot be made conditional"

# Templates that are not screens: partials, HTMX fragments, anything rendered
# inside something else. Optional, comma-separated basenames.
fragments_declared=$(awk '
  NR==1 && $0!="---" { exit }
  NR==1 { infm=1; next }
  infm && $0=="---" { exit }
  infm && /^fragments:/ { sub(/^fragments:[ \t]*/,""); gsub(/,/," "); print; exit }
' "$UX")

# Every declared ui_path must exist. A stale path silently disables the gate,
# which is worse than no gate at all.
for p in $(echo "$ui_paths" | tr ',' ' '); do
  [ -n "$p" ] || continue
  base=$(echo "$p" | sed 's#/\*\*.*$##; s#/\*.*$##')
  [ -e "$base" ] || warn "ui_path $p does not exist on disk"
done

# --- no literal values -------------------------------------------------------
# The contract points at tokens.css; it never carries a value. Without this the
# file rots into a stale copy of the stylesheet.
lit=$(grep -nE '#[0-9a-fA-F]{3,8}\b|[0-9]+px|[0-9]+rem' "$UX" | grep -v '^\s*[0-9]*:\s*<!--' || true)
[ -z "$lit" ] || {
  echo "$lit" | while IFS= read -r l; do
    printf 'UX: literal value, values belong in tokens.css: %s\n' "$l" >&2
  done
  fail=1
}

# --- table extraction --------------------------------------------------------
# First column of every data row under a given "## Section" heading.
col1() {
  awk -v sec="$1" '
    $0 ~ "^## " sec "[ \t]*$" { in_s=1; next }
    /^## / { in_s=0 }
    in_s && /^\|/ {
      line=$0
      if (line ~ /^\|[ \t]*-+/) next        # separator row
      sub(/^\|[ \t]*/,"",line)
      split(line, a, "|")
      gsub(/^[ \t]+|[ \t]+$/,"",a[1])
      gsub(/\*/,"",a[1])
      if (a[1]=="id" || a[1]=="block" || a[1]=="") next
      print a[1]
    }
  ' "$2"
}

# Second column (the file/template) of every data row under a section.
col2() {
  awk -v sec="$1" '
    $0 ~ "^## " sec "[ \t]*$" { in_s=1; next }
    /^## / { in_s=0 }
    in_s && /^\|/ {
      line=$0
      if (line ~ /^\|[ \t]*-+/) next
      sub(/^\|[ \t]*/,"",line)
      split(line, a, "|")
      gsub(/^[ \t]+|[ \t]+$/,"",a[2])
      gsub(/\*/,"",a[2])
      if (a[2]=="template" || a[2]=="file" || a[2]=="") next
      print a[2]
    }
  ' "$2"
}

screens=$(col1 Screens "$UX" || true)
templates_declared=$(col2 Screens "$UX" || true)
blocks_declared=$(col2 Components "$UX" || true)

[ -n "$screens" ] || warn "## Screens has no row: a UI contract with no screen is not a contract"

# Every screen row must fill the two intent columns. If you cannot name the
# dominant action and the tension relieved, the screen is built, not designed.
bare=$(awk '
  /^## Screens[ \t]*$/ { in_s=1; next }
  /^## / { in_s=0 }
  in_s && /^\|/ {
    if ($0 ~ /^\|[ \t]*-+/) next
    line=$0; sub(/^\|[ \t]*/,"",line); sub(/\|[ \t]*$/,"",line)
    n=split(line, a, "|")
    for (i=1;i<=n;i++) { gsub(/^[ \t]+|[ \t]+$/,"",a[i]); gsub(/\*/,"",a[i]) }
    if (a[1]=="id" || a[1]=="") next
    # An unfilled TODO is not an intent: treating it as filled would let a whole
    # table ship with the two columns that carry the design intent left blank.
    if (n < 4 || a[3]=="" || a[4]=="" || a[3]=="TODO" || a[4]=="TODO") print a[1]
  }
' "$UX")
[ -z "$bare" ] || {
  for s in $bare; do
    printf 'UX: screen %s has no dominant action or no tension relieved\n' "$s" >&2
  done
  fail=1
}

# --- templates on disk vs Screens table --------------------------------------
# Filesystem only. Deliberately not "every served route": that needs a
# per-framework parser, breaks on dynamic routes, and ends up bypassed.
tpl_dir=""
for d in web/templates templates internal/web/templates views; do
  [ -d "$d" ] && { tpl_dir="$d"; break; }
done

if [ -n "$tpl_dir" ]; then
  for f in $(find "$tpl_dir" -type f \( -name '*.html' -o -name '*.tmpl' -o -name '*.templ' \) 2>/dev/null); do
    b=$(basename "$f")
    # Partials and fragments are not screens. Name conventions catch the obvious
    # ones; everything else must be declared in the frontmatter, because no
    # heuristic recovers it. Content is not a signal: in a Go/HTMX codebase every
    # template can open with {{define}}, pages included, so keying on that
    # excludes everything and silently disables this check, which is worse than
    # the noise it was meant to remove. What separates a page from a fragment is
    # whether the handler composes it with the layout, and only the project knows.
    case "$b" in _*|*partial*|*layout*|*fragment*) continue ;; esac
    case " $fragments_declared " in *" $b "*) continue ;; esac
    echo "$templates_declared" | grep -qxF "$b" \
      || warn "template $b has no row in ## Screens (declare it in frontmatter 'fragments:' if it is not a screen)"
  done
  for t in $templates_declared; do
    [ -n "$t" ] || continue
    find "$tpl_dir" -type f -name "$t" 2>/dev/null | grep -q . \
      || warn "## Screens declares $t, which does not exist under $tpl_dir/"
  done
fi

# --- CSS blocks on disk vs Components table ----------------------------------
blk_dir=""
for d in web/css/blocks assets/css/blocks static/css/blocks css/blocks; do
  [ -d "$d" ] && { blk_dir="$d"; break; }
done

if [ -n "$blk_dir" ]; then
  for f in "$blk_dir"/*.css; do
    [ -e "$f" ] || continue
    rel="blocks/$(basename "$f")"
    echo "$blocks_declared" | grep -qxF "$rel" \
      || warn "$rel has no row in ## Components"
  done
  for b in $blocks_declared; do
    [ -n "$b" ] || continue
    [ -e "$(dirname "$blk_dir")/$b" ] \
      || warn "## Components declares $b, which does not exist"
  done
fi

[ "$fail" -eq 0 ] && echo "UX: $UX conformant (UX contract v1)"
exit "$fail"
