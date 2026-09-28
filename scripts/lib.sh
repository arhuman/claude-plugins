# Shared prologue of the repo's check scripts. Sourced, never executed.
#
# Two things every remaining check rediscovered on its own: which files make
# up the shipped plugin and its generated OpenCode tree, and how to read one
# field out of a frontmatter block. Both live here once. Each check keeps its
# own logic, message and exit code; this file decides no verdict.
#
# Source it from a script in scripts/ with:
#   . "$(dirname "$0")/lib.sh"
# It sets nothing that depends on the caller's arguments and runs no command
# at load time, so sourcing it is free of side effects.

# The one plugin this repo ships, and the surface a user or CI actually
# receives (design notes under .claude/ are private and never part of it).
# shellcheck disable=SC2034 # read by the sourcing scripts, not here
PLUGIN_ROOT=plugins/10x
# shellcheck disable=SC2034 # read by the sourcing scripts, not here
SHIPPED_SURFACE='plugins/ README.md .github/'

# File sets, one path per line on stdout. Globs are the same ones the checks
# used individually, so a set evaluates to exactly what each check saw before.
# Names carry no whitespace in this tree, which is what lets a caller iterate
# with `for f in $(plugin_skills)`.
plugin_skills() { for f in plugins/*/skills/*/SKILL.md; do [ -f "$f" ] && echo "$f"; done; }
plugin_agents() { for f in plugins/*/agents/*.md; do [ -f "$f" ] && echo "$f"; done; }
plugin_commands() { for f in plugins/*/commands/*.md; do [ -f "$f" ] && echo "$f"; done; }
gen_commands() { for f in opencode/commands/*.md; do [ -f "$f" ] && echo "$f"; done; }
gen_agents() { for f in opencode/agents/*.md; do [ -f "$f" ] && echo "$f"; done; }

# fm_field <file> <key>: print the value of <key> from the first frontmatter
# block, leading whitespace stripped, empty when the key or the block is
# absent. Frontmatter only: the same key written in prose further down is not
# a declaration. The value is returned as written, quotes included, so a
# caller decides whether quoting matters to it.
fm_field() {
  awk -v key="$2" '
    NR == 1 && $0 == "---" { in_fm = 1; next }
    in_fm && $0 == "---"   { exit }
    in_fm && index($0, key ":") == 1 {
      sub("^" key ":[[:space:]]*", ""); print; exit
    }
  ' "$1"
}
