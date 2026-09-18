#!/bin/sh
# Install (default) or remove (--uninstall) the OpenCode-facing tree as
# symlinks under ~/.config/opencode/: generated commands and agents from
# opencode/, and the skills straight from plugins/10x/skills/ (they are
# OpenCode-valid at source; _shared is linked as a sibling so the skills'
# ../_shared/references/... paths keep resolving).
#
# Idempotent. Never touches a target that exists and is not a symlink:
# real user files are warned about and skipped, both ways. Uninstall only
# removes symlinks that resolve into this repo.
set -u

REPO=$(git rev-parse --show-toplevel 2>/dev/null)
[ -n "$REPO" ] || REPO=$(cd "$(dirname "$0")/.." && pwd)
CFG="$HOME/.config/opencode"
MODE=${1:-install}

linked=0 skipped=0 removed=0

link_one() {
  src=$1 dst=$2
  if [ ! -e "$src" ]; then
    echo "missing source: $src (run sh scripts/gen-opencode.sh first)" >&2
    exit 1
  fi
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "skip (exists, not a symlink): $dst"
    skipped=$((skipped + 1))
    return
  fi
  ln -sfn "$src" "$dst"
  echo "linked: $dst -> $src"
  linked=$((linked + 1))
}

unlink_one() {
  # Same (source, destination) signature as link_one; source is unused.
  dst=$2
  [ -L "$dst" ] || return 0
  case "$(readlink "$dst")" in
    "$REPO"/*)
      rm "$dst"
      echo "removed: $dst"
      removed=$((removed + 1))
      ;;
    *)
      echo "skip (symlink not owned by this repo): $dst"
      skipped=$((skipped + 1))
      ;;
  esac
}

each_target() {
  # Calls $1 with (source, destination) for every artifact.
  act=$1
  for f in "$REPO"/opencode/commands/*.md; do
    "$act" "$f" "$CFG/commands/$(basename "$f")"
  done
  for f in "$REPO"/opencode/agents/*.md; do
    "$act" "$f" "$CFG/agents/$(basename "$f")"
  done
  for d in "$REPO"/plugins/10x/skills/*/; do
    d=${d%/}
    name=$(basename "$d")
    if [ -f "$d/SKILL.md" ] || [ "$name" = "_shared" ]; then
      "$act" "$d" "$CFG/skills/$name"
    fi
  done
}

case "$MODE" in
  install)
    mkdir -p "$CFG/commands" "$CFG/agents" "$CFG/skills"
    each_target link_one
    echo "done: $linked linked, $skipped skipped"
    ;;
  --uninstall)
    each_target unlink_one
    echo "done: $removed removed, $skipped skipped"
    ;;
  *)
    echo "usage: sh scripts/install-opencode.sh [--uninstall]" >&2
    exit 2
    ;;
esac
