# Register

These sentence-level rules support `senior-voice` and `documentation-rules`.
They apply to reader-facing technical prose and code comments. A consuming
skill owns the document shape.

## Reader model

Assume technical competence and no project, runtime, or incident context.
Explain project-specific shorthand and unusual mechanisms. Do not explain
general software concepts unless the reader asks.

## Rules

- Lead with observable behavior, the rule, or the consequence. Follow with the
  mechanism when it helps verification or action.
- Use plain verbs and concrete subjects. Name the identifier, file, command, or
  user action instead of `the system`, `the layer`, `the flow`, or `the
  architecture`.
- Explain an unusual or project-specific term on first use. Keep an exact
  technical term when it adds necessary precision.
- Prefer shorter wording only when it is equally accurate.
- Preserve confidence. Keep verified facts, supported inferences, and unknowns
  distinct.
- Include identifiers, paths, commands, and measurements only when they help
  someone verify, locate, change, or escalate the claim.

## Tests

**Two-term test.** If one sentence contains two or more terms this reader could
not define, split it and explain the project-specific term. Do not gloss basic
software concepts for an expert audience.

**Portability test.** If the sentence would be true, unchanged, in twenty
unrelated codebases, it carries no information. Delete it or replace it with the
specific constraint it was gesturing at.

**Falsifiability test.** Keep only claims that could be wrong. A claim that
cannot fail is decoration.

**Verification test.** Every cited issue, incident, ADR, commit, or measurement
must exist and still support the claim. A stale accurate sentence becomes a
false one when the code changes.

## Forbidden

- Filler: successfully, comprehensive, seamlessly, leverages, robust,
  cutting-edge, powerful.
- Condescending shortcuts: obviously, simply, just.
- Unjustified hedges: typically, generally, in most cases, could potentially,
  may be suboptimal. A hedge is valid only when the uncertainty is real and
  stated.
- Em dash and en dash punctuation. Hyphens and numeric ranges are fine.
- Emojis, except a severity marker defined by a consuming template.
- Internal roadmap markers in prose read outside the project.
