---
name: senior-voice
description: 'Plain, precise register for reader-facing technical prose: review findings, audit summaries, README text, release notes, status updates, and implementation explanations. Leads with behavior and consequence, then gives the mechanism and useful technical anchors. Use when writing or rewriting technical material for readers who may not know the codebase or incident. Not for document shape, review scoring, commit messages, or code-comment contracts.'
---

# Senior voice

Seniority shows in the quality of the explanation, not in the effort needed to
read it. State what the system does and why it matters before asking the reader
to decode how the code is arranged.

This skill owns register. It does not prescribe report sections, finding layers,
severity labels, score tables, or coding-agent prompts. The skill or command
that produces the document owns its shape.

## Reader model

Assume the reader is technically competent but unfamiliar with this codebase,
this incident, and this project's internal shorthand. Explain project-specific
terms and unusual mechanisms. Do not explain general software concepts unless
the reader asks.

## Tone contract

- **Must lead with behavior or the rule.** Name the implementation mechanism
  after the reader understands what it controls.
- **Must preserve meaning and consequence.** Plain wording must not weaken
  severity, omit a risk, or turn uncertainty into certainty.
- **Must remain self-contained.** Do not rely on the reader knowing an earlier
  bug, outage, pull request, or conversation.
- **Should use plain verbs and concrete subjects.** Prefer `checks` to
  `enforces`, and name the server, command, file, or user action instead of an
  abstract layer or flow.
- **Should explain project-specific terms on first use.** Prefer the plain
  meaning when the technical term adds no useful precision.
- **Should keep technical anchors only when they help someone verify, locate,
  change, or escalate the claim.** Do not add identifiers merely to sound
  precise.
- **May use dense technical language for an expert-only audience.** Keep the
  conclusion and confidence clear; do not add basic explanations the reader
  does not need.

## Default explanation flow

Use this flow when it helps. It is an ordering heuristic, not a required
template:

1. **Rule or behavior:** what is true in plain language.
2. **Check or mechanism:** how the implementation maintains it.
3. **Failure behavior:** what happens when the rule is violated.
4. **Reason:** what risk this prevents or what decision it supports.
5. **Anchor:** the identifier, path, metric, or command needed to act.

Use short paragraphs when one sentence would combine the rule, mechanism,
exception, consequence, history, and measurement.

## Precision guardrails

### Confidence

Keep verified, likely, and unknown claims distinct:

- `confirmed by server.go:197-210` for evidence already checked;
- `likely caused by the retry loop` for a supported but unproven explanation;
- `unknown until the production configuration is checked` when evidence is
  missing.

Do not add a hedge to a verified fact. Do not present an inference as a fact.

### Technical terms

The list in [jargon](references/jargon.md) is diagnostic, not a banned-word
list. If a term is necessary, explain its plain meaning first or make its meaning
clear in the same sentence. Keep exact terms when they matter for safety,
security, compliance, or implementation.

### Anchors and history

Include a path, identifier, metric, command, or historical detail when the
reader needs it to verify or act. Omit it when it merely proves that the writer
knows the implementation. Explain the relevant history instead of referring to
`the original bug` without context.

## Rewrite signals

| If the prose starts with | Rewrite toward |
|---|---|
| An internal mechanism | Observable behavior, then the mechanism |
| An abstract category | The concrete rule or consequence |
| An identifier carrying the meaning | Plain meaning before the identifier |
| Incident shorthand | The relevant fact from the incident |
| A metric name | What was measured, its scope, and why it matters |
| A jargon-only conclusion | A consequence the reader can understand |
| Drama or cleverness | A direct statement of behavior or risk |
| `simply`, `just`, or `obviously` | A direct instruction without judgment |
| A bureaucratic hedge | The required action, unless uncertainty is real |

## Examples

### Behavior before mechanism

Avoid:

> The loopback invariant is enforced by `loopbackAddr`, which log.Fatals on a
> non-loopback address and prevents silently serving the LAN.

Prefer:

> The server is restricted to the local machine, and this rule is checked at
> startup.
>
> `loopbackAddr` (`server.go:197-210`) rejects addresses that would make the
> server reachable from other machines. If the address is unsafe, the
> application refuses to start. This prevents accidental network exposure.

### Measurement before gate name

Avoid:

> Gated statement coverage is 83.8%, above the `COVER_MIN=80` ratchet.

Prefer:

> Tests run 83.8% of executable statements, excluding the vendored
> `internal/yamlscan` code. The project requires at least 80%, so future changes
> must not reduce coverage below that floor.

### Direct without drama, judgment, or ceremony

| Avoid | Prefer |
|---|---|
| This dangerously blows the blast radius wide open. | One database change can break several screens at once. |
| Simply use localhost. | Configure the server to listen only on `localhost`. |
| It may be advisable to consider improving validation. | Add validation before saving the configuration. |

## Completion check

- Does the opening state behavior, a rule, or a consequence rather than an
  implementation detail?
- Can the reader understand the decision without knowing the codebase or the
  original incident?
- Are unusual project terms explained without teaching basic concepts?
- Are confidence and severity unchanged?
- Does every technical anchor help the reader verify or act?
- Can any dense sentence be split without losing meaning?

For sentence-level tests and forbidden filler, read
[register](references/register.md).
