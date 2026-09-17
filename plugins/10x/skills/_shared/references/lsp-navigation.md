# LSP pull navigation

Canonical protocol for querying the language server (the `LSP` tool; gopls for
Go) instead of grep when the question is about a *symbol*, not about text.
Held here once; skills and agents that need it link here rather than restating
it.

## When to pull LSP instead of grep

Grep answers in milliseconds and wins on distinctive names and literal text
(error messages, TODOs, config keys). It loses when the name forces a
disambiguation loop, because it cannot resolve types:

- **Common or short name** (`Process`, `New`, `run`, `id`): grep returns
  comments, strings, and unrelated fields; each refinement round is a model
  turn plus follow-up Reads. `findReferences` returns the exact list once.
- **Homonyms**: two methods with the same name on different types. Grep cannot
  tell them apart; the language server can. This is the case that turns a
  mechanical rename into a wrong-site edit.
- **Interfaces**: Go has no `implements` keyword, so there is no string to
  grep. `goToImplementation` is the only direct answer to "what satisfies
  this interface".
- **Call direction**: "who calls X" / "what does X call" is
  `incomingCalls` / `outgoingCalls`, not a text search.

## Position protocol

The LSP tool takes a file, line, and column, never a bare name. The sequence
is always:

1. Grep the *declaration* (narrow pattern: `func X`, `type X`, `interface`),
   which is cheap and unambiguous.
2. Call the LSP operation at that position (1-based line and character).

Skipping step 1 and guessing a position returns wrong-symbol results without
an error, which is worse than no result.

## Operations in practice

| Question | Operation |
|----------|-----------|
| Every use of this symbol, resolved by type | `findReferences` |
| What satisfies this interface | `goToImplementation` |
| Who calls this function | `incomingCalls` |
| What this function calls | `outgoingCalls` |
| All symbols in a file / matching a name | `documentSymbol` / `workspaceSymbol` |

`findReferences` output is a list of `file:line` positions, not code content:
treat it as the exhaustive checklist and read only the sites you must edit.

## Fallback: degrade loudly

The tool needs a language server configured for the file type. When the call
errors (non-Go repo, gopls not installed), do the same search with grep and
prefix the conclusion `UNVERIFIED:`, because a grep-built reference list is a
claim, not a measurement, and downstream gates must see the difference. Never skip
the search because the server is missing, and never present the grep result
as resolved.
