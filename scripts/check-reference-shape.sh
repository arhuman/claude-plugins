#!/bin/sh
# Keep skill references readable when Claude loads only part of them.
#
# (a) A Markdown reference over 100 lines carries a `## Contents` section with
#     one `- <heading>` line per `##` heading, so a partial read still shows
#     the whole file's shape. Headings inside code fences are sample content,
#     not sections, and are not required.
# (b) A file a Markdown reference cites by name within the same skill is also
#     linked from that skill's SKILL.md as `references/<name>`. Claude may only
#     preview a file reached through another reference; the SKILL.md link is
#     the one level deep path. _shared references serve every skill and are
#     exempt from (b).
set -u
. "$(dirname "$0")/lib.sh"
fail=0

contents_missing() {
  awk '
    /^```/ { fence = !fence; next }
    fence { next }
    /^## Contents[[:space:]]*$/ { in_toc = 1; has_toc = 1; next }
    /^## / {
      in_toc = 0
      h = $0; sub(/^## /, "", h); sub(/[[:space:]]+$/, "", h)
      heads[++n] = h; next
    }
    in_toc && /^- / { e = $0; sub(/^- /, "", e); sub(/[[:space:]]+$/, "", e); listed[e] = 1 }
    END {
      if (!has_toc) { print "no ## Contents section"; exit }
      for (i = 1; i <= n; i++) if (!(heads[i] in listed)) print "Contents does not list: " heads[i]
    }
  ' "$1"
}

for f in "$PLUGIN_ROOT"/skills/*/references/*.md; do
  [ -f "$f" ] || continue
  [ "$(wc -l < "$f")" -gt 100 ] || continue
  missing=$(contents_missing "$f")
  if [ -n "$missing" ]; then
    printf '%s\n' "$missing" | sed "s|^|CONTENTS: $f: |"
    fail=1
  fi
done

for skill in $(plugin_skills); do
  dir=$(dirname "$skill")
  case "$dir" in */_shared) continue ;; esac
  [ -d "$dir/references" ] || continue
  for target in "$dir"/references/*; do
    name=$(basename "$target")
    pattern="(^|[^A-Za-z0-9._/-])(\\./|references/)?$(printf '%s' "$name" | sed 's/\./\\./g')([^A-Za-z0-9._-]|$)"
    for citer in "$dir"/references/*.md; do
      [ "$citer" = "$target" ] && continue
      grep -qE "$pattern" "$citer" || continue
      if ! grep -qF "references/$name" "$skill"; then
        echo "NESTED: $citer cites $name, which $skill does not link as references/$name"
        fail=1
      fi
      break
    done
  done
done

exit $fail
