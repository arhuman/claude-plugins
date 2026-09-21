#!/bin/sh
# Inside ```makefile fences of the Makefile templates, no line may start
# with spaces: recipes need tabs, everything else starts at column 0.
set -u
fail=0
for f in plugins/*/skills/makefile/references/makefile-*.md; do
  awk -v file="$f" '
    /^```makefile/ { inblock = 1; next }
    /^```/         { inblock = 0; next }
    inblock && /^ +[^ ]/ { printf "SPACE-INDENT %s:%d: %s\n", file, NR, $0; found = 1 }
    END { exit found }
  ' "$f" || fail=1
done
exit $fail
