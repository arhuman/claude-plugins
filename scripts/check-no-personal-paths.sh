#!/bin/sh
# No tracked file may carry a home-directory path.
#
# The PAL server is configured with two absolute paths under someone's home
# (/Users/<name>/code_perso/pal-mcp-server/...). Committing a resolved config
# would publish a private tree and would name a directory that exists on
# exactly one machine. The repo ships a template with placeholders instead
# (scripts/opencode-mcp-pal.template.json) and the installer resolves it into
# the user's own config, so a match here means a resolved path leaked back in.
#
# Covers tracked AND not-yet-tracked files, minus what .gitignore excludes: a
# leak arrives in a new file, so checking `git ls-files` alone would pass on
# exactly the commit that introduces one. .claude/ is gitignored private
# working context and legitimately full of local paths.
set -u

fail=0

# A literal $HOME or ~ in prose or a command is how to write a home path
# portably, so only expanded forms are violations.
pattern='/Users/[A-Za-z0-9._-]\{1,\}\|/home/[A-Za-z0-9._-]\{1,\}'

for f in $(git ls-files --cached --others --exclude-standard); do
  case "$f" in
    scripts/check-no-personal-paths.sh) continue ;;  # names the pattern itself
  esac
  [ -f "$f" ] || continue

  hits=$(grep -n "$pattern" "$f" 2>/dev/null \
    | grep -v '/home/runner' \
    || true)
  if [ -n "$hits" ]; then
    echo "PERSONAL PATH: $f"
    printf '%s\n' "$hits" | sed 's/^/      /'
    fail=1
  fi
done

if [ "$fail" -eq 1 ]; then
  echo
  echo 'Use a placeholder resolved at install time, $HOME, or ~ instead.'
  echo 'See scripts/opencode-mcp-pal.template.json for the pattern.'
  exit 1
fi

echo "No home-directory paths in tracked or new files."
