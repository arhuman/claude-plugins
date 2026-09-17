#!/bin/sh
# Every relative markdown link in plugin .md files resolves to a real file.
#
# check-skill-references.sh only covers references/ pointers named in a
# SKILL.md; this covers every [text](path) link in every plugin markdown
# file (skills, commands, agents), so a renamed or deleted target breaks CI
# instead of silently 404ing when the model follows the link.
#
# Skipped: fenced code blocks and inline code spans (Go generics like
# `[T any](slice []T)` and regex alternations match the link pattern),
# absolute URLs (scheme:), pure anchors (#...), absolute paths, and template
# placeholders ({...}). A trailing #anchor on a relative link is stripped
# before the check.
set -u
fail=0
for file in $(find plugins -name '*.md' -not -path '*/node_modules/*'); do
  dir=$(dirname "$file")
  links=$(awk '/^ *(```|~~~)/ { infence = !infence; next } !infence' "$file" \
    | sed -E 's/`[^`]*`//g' \
    | grep -oE '\]\(([^)]+)\)' | sed -E 's/^\]\(//; s/\)$//; s/#.*$//' \
    | grep -vE '^$|^[a-z][a-z0-9+.-]*:|^/|[{ ]' || true)
  for link in $links; do
    if [ ! -e "$dir/$link" ]; then
      echo "BROKEN LINK: $file -> $link"
      fail=1
    fi
  done
done
exit $fail
