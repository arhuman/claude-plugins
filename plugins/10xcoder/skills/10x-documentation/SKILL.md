---
name: 10x-documentation
description: Rules for writing and updating documentation. Use for any non-trivial documentation task in README.md, markdown files, text files, and code comments.
---

# 10x Documentation

Rules for producing clear, accurate, and maintainable documentation.

## Style — Global Rules

These apply to all output: changelogs, READMEs, code comments, ADRs, API docs.

**Never use:**
- Em dashes (`—`). Use a comma, a colon, or rewrite the sentence.
- Emojis anywhere.
- Numbered lists unless the order is strictly required (installation steps, migration sequences). Use plain bullet lists otherwise.
- Filler phrases: "successfully", "comprehensive", "seamlessly", "leverages", "robust", "cutting-edge".
- Passive voice when active is clearer.
- Hedge words without reason: "typically", "generally", "in most cases" — say what it does.

**Always:**
- Write in the same language as the surrounding text or comments.
- Use active voice and present tense.
- Keep sentences short. One idea per sentence.
- Say what something does before explaining how.
- Write for the reader's knowledge level, not to demonstrate thoroughness.

---

## Changelog

Format: [Keep a Changelog](https://keepachangelog.com). Group under `[Unreleased]` by date.
Categories: `Added`, `Changed`, `Fixed`, `Removed`.

Good entry: `Added rate limiting middleware to the API router`
Bad entry: `Successfully implemented a comprehensive rate limiting solution that seamlessly integrates with the existing API infrastructure`

---

## Code Comments

- Explain *why*, not *what*. The code shows what; the comment explains the reasoning.
- Document parameters, return values, and error conditions for all exported functions.
- Follow language conventions: GoDoc for Go, JSDoc for JavaScript, docstrings for Python.
- Include short, working code examples for non-obvious usage.
- Keep comments current when code changes. A stale comment is worse than no comment.

---

## README and User Guides

Structure in this order:
- What the project does (one paragraph, no marketing language)
- Quick start (the minimum to get something running)
- Installation and setup
- Configuration options
- Component overview and how they interact
- Troubleshooting
- Links to detailed docs

---

## Architecture Decision Records

File location: `.claude/doc/ADR.md` (single accumulated file, gitignored). Append new entries; do not create separate files.

Required sections: Status, Context, Decision, Consequences, Alternatives Considered.

Status values: `Proposed` | `Accepted` | `Deprecated` | `Superseded by ADR-NNNN`

Link related ADRs when the decision builds on or contradicts a previous one.

---

## API Documentation

- Use OpenAPI/Swagger annotations on every handler tied to a route.
- Document all public interfaces and methods.
- For each endpoint: request shape, response shape, authentication requirements, possible error codes.
- Include a realistic example request and response, not a placeholder.

---

## Special Annotations

When relevant, add a clearly marked note for:
- Version compatibility (which version this applies to)
- Deprecations (what replaces the deprecated feature)
- Security considerations
- Performance characteristics that affect usage decisions
