# PAL routing (single source of truth)

Which PAL tool to call for which need. Agents and commands that consult PAL
point here instead of restating the rows: a copy drifts the moment this table
changes, and the duplication check guards the operative wording below.

Tool names are bare. The id you call is the harness's own form, from
`tool-names.md` in this directory: Claude Code `mcp__pal__<tool>`, OpenCode
`pal_<tool>`.

| Need | Tool | Rule |
|------|------|------|
| A fact, a draft, or a second opinion | `chat` | One model answers once; use it when the question needs no deliberation. |
| A decision between alternatives | `consensus` | Several models argue before a verdict; use it when a decision has more than one defensible answer. |
| A design, performance, or security investigation | `thinkdeep` | One model works in steps with your files; use it when the answer needs evidence from the code, including a refactor touching three or more files. |
| A failure whose cause resists the obvious checks | `debug` | Hypothesis-driven root-cause analysis; use it when a failure is still unknown after the obvious checks. |
| Any call where no model is named | `listmodels` | Run it first whenever no model is named; pick from what it lists. |

Pass identical prompts when several tools or models are compared, and give
files through the tool's file parameter rather than pasting them, so the
model reads what the repo holds rather than what fit in the prompt.

Not covered here: `/evaluate` names its three external models explicitly in
its own "Model Access" section, which is a model list, not a routing choice.
