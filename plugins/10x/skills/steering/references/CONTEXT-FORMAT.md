# CONTEXT.md Format

Owned paths below; foreign repos use `.claude/project/context.md` per steering, same shape.

## Structure

```md
# {Context Name}

{One or two sentences: what this context is and why it exists.}

## Language

**Order**:
{One or two sentences defining the term.}
_Avoid_: Purchase, transaction
```

Replace all braced placeholders with real content, removing braces/instructions.

## Rules

- Pick one preferred name; list rejected aliases under `_Avoid_`.
- Record ambiguous usage and a clear resolution in "Flagged ambiguities".
- Define what a term IS in at most two sentences. Use bold term names and obvious cardinalities to express relationships.
- Only project-context-specific domain concepts, never general programming concepts (timeouts, error types, utility patterns). Check this distinction before adding a term.
- Group natural clusters under subheadings; a cohesive context may remain flat.
- Include dev/domain-expert example dialogue showing natural interactions and boundaries.

## Single vs multi-context repos

- Existing `CONTEXT-MAP.md`: read it to locate contexts. Root map lists context names linked to their CONTEXT.md paths and responsibilities, then Relationships with direction, integration mechanism/events or shared types.
- Only root `CONTEXT.md`: single context.
- Neither: create root CONTEXT.md lazily on first resolved term.

For multiple contexts, infer the relevant context from the topic; ask when unclear.
