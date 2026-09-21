#!/bin/sh
# PostToolUse hook: after a Write/Edit touching CLAUDE.md, remind the model
# to resync the project context scaffold via the steering skill.
command -v jq >/dev/null 2>&1 || exit 0
fp=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)
case "$fp" in
  *CLAUDE.md)
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"CLAUDE.md was modified. Run /10x:plan check to keep the project context scaffold (.claude/project/, docs/ux.md) in sync."}}'
    ;;
esac
exit 0
