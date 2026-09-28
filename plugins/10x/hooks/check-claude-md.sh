#!/bin/sh
# PostToolUse hook: after a Write/Edit touching CLAUDE.md, remind the model
# to resync the project context scaffold via the steering skill.
# Resolve through symlinks: the installer links these hooks into a config tree,
# where dirname "$0" is the link's directory and lib.sh would not be found.
_self=$0
while [ -L "$_self" ]; do
  _link=$(readlink "$_self")
  case "$_link" in /*) _self=$_link ;; *) _self=$(dirname "$_self")/$_link ;; esac
done
. "$(dirname "$_self")/lib.sh"
hook_payload
fp=$(hook_field file_path)
case "$fp" in
  *CLAUDE.md)
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"CLAUDE.md was modified. Run /10x:plan check to keep the project context scaffold (.claude/project/, docs/ux.md) in sync."}}'
    ;;
esac
exit 0
