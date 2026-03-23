---
name: lang-sql
description: SQL coding best practices and patterns. Use when working with SQL files, writing migrations, or reviewing schema design.
---

# lang-sql

This skill defines rules for writing correct, maintainable, and production-safe SQL — covering schema design, migrations, queries, and indexing.

## Reference Guide

- PostgreSQL documentation: https://www.postgresql.org/docs/current/
- Use `EXPLAIN ANALYZE` to verify query plans before merging slow queries
- `TIMESTAMPTZ` (with timezone) over `TIMESTAMP` for any datetime column

## Architecture Principles

### Schema Design
- Use `SERIAL PRIMARY KEY` for surrogate keys
- Prefer `TEXT` over `VARCHAR(n)` unless a hard limit is meaningful (e.g. `VARCHAR(45)` for IP addresses, `VARCHAR(500)` for tokens)
- Use `TIMESTAMPTZ NOT NULL DEFAULT NOW()` for audit timestamps (`created_at`, `computed_at`)
- Nullable columns should be explicit: use `DEFAULT NULL` when adding optional columns
- Use `UNIQUE` constraints on the table, not just application-level validation
- Use `CHECK` constraints to enforce domain rules at the DB level (e.g. state machines, enum-like values)

### State Machines in SQL
Model lifecycle states as a `VARCHAR` column with a `CHECK` constraint listing all valid values:
```sql
ADD COLUMN state VARCHAR(20) NOT NULL DEFAULT 'created'
    CHECK (state IN ('created', 'answering', 'submitted', 'completed', 'expired'));
COMMENT ON COLUMN quizzes.state IS 'Quiz lifecycle: created → answering → submitted → completed (or expired)';
```
Document the transition flow in a `COMMENT ON COLUMN`.

### Foreign Keys
- Add `ON DELETE CASCADE` on child tables when child rows are meaningless without the parent
- Remove FK constraints intentionally when data preservation matters more than referential integrity (e.g. soft-delete QCMs while preserving quiz history) — always document this trade-off in the migration comment
- Never silently drop an FK; write a comment explaining why

### JSON Columns
- Use `JSONB` (not `JSON`) for structured data that may be queried or indexed
- Only use JSONB when the structure is variable or too large for normalized columns (e.g. `scores`, `question_sequence`)
- Avoid JSONB for fields that are queried by value — normalize them instead

## MUST DO

- **One migration = one concern**: each SQL file addresses a single schema change
- **Number migrations sequentially**: `NN-description.sql` (e.g. `21-add-ip-address.sql`)
- **Write a comment header** explaining *why* the migration exists, especially for non-obvious changes
- **Use `IF EXISTS` / `IF NOT EXISTS`** on `DROP` and `CREATE INDEX` in migrations to make them idempotent
- **Use partial indexes** when a condition is almost always true (e.g. `WHERE session_token IS NOT NULL`)
- **Use `ON CONFLICT ... DO UPDATE`** (upsert) instead of separate SELECT + INSERT/UPDATE
- **Use CTEs** (`WITH`) to make complex queries readable; avoid deeply nested subqueries
- **Use `COALESCE`** to handle NULLs explicitly in calculations rather than relying on implicit NULL propagation
- **Use `EXTRACT(EPOCH FROM interval) * 1000`** for millisecond durations from timestamp deltas
- **Use `LAG()` window function** for computing deltas between consecutive rows (e.g. answer timing)
- **Parameterize all queries** — never interpolate user input into SQL strings

## MUST NOT DO

- Do not use `SELECT *` in application queries — always list columns explicitly
- Do not add columns without a `DEFAULT` on a large live table (it locks the table in old PG versions)
- Do not use `TIMESTAMP` without timezone — always use `TIMESTAMPTZ`
- Do not drop a foreign key without a comment explaining the trade-off
- Do not use `JSON` — always `JSONB`
- Do not put business logic (scoring, state transitions) in SQL — keep it in the application layer
- Do not use `COUNT(*)` to check existence — use `EXISTS (SELECT 1 FROM ...)` instead

## Coding Style

### Formatting
- Keywords in UPPERCASE: `SELECT`, `FROM`, `WHERE`, `INSERT`, `ON DELETE CASCADE`, etc.
- Table and column names in `snake_case`
- Indent continuation lines by one tab/4 spaces
- One column per line in `CREATE TABLE` and `ALTER TABLE ADD COLUMN` blocks

### Migration Files
```sql
-- Migration: Short description of what this migration does
--
-- Purpose: Why this change is needed
-- Impact:  What tables/columns/indexes are affected
-- Trade-off: Any integrity or performance trade-off (if applicable)

ALTER TABLE quizzes
ADD COLUMN ip_address VARCHAR(45) DEFAULT NULL;
```

### Indexes
```sql
-- Partial index: only index rows where token is set
CREATE INDEX idx_quizzes_session_token ON quizzes(session_token) WHERE session_token IS NOT NULL;

-- Composite index for analytics time-range queries
CREATE INDEX idx_answers_timing ON answers(quiz_id, answered_at);
```

### Upsert Pattern
```sql
INSERT INTO answers (quiz_id, question_id, choice_id)
VALUES ($1, $2, $3)
ON CONFLICT (quiz_id, question_id)
DO UPDATE SET choice_id = EXCLUDED.choice_id;
```

### Window Function for Timing
```sql
WITH ordered_answers AS (
    SELECT
        question_id,
        answered_at,
        LAG(answered_at) OVER (ORDER BY answered_at, id) AS prev_answered_at
    FROM answers
    WHERE quiz_id = $1
)
SELECT EXTRACT(EPOCH FROM (
    answered_at - COALESCE(prev_answered_at, (SELECT created_at FROM quizzes WHERE id = $1))
)) * 1000
FROM ordered_answers
WHERE question_id = $2;
```

## Quality Standards

- Every migration must be tested on a local DB before committing
- Migrations are **not reversible** by default — write a separate rollback file only when rollback is planned
- All indexes on high-write tables must be justified (indexes slow writes)
- `CHECK` constraints must cover all valid values of an enum-like column
- IP address columns use `VARCHAR(45)` to support both IPv4 and IPv6

## Agent Behavior

- When asked to add a column, always produce a numbered migration file in `conf/initdb/`
- When modifying a `CHECK` constraint, drop the old one first (`DROP CONSTRAINT IF EXISTS`) then add the new one
- When writing a JOIN query, always use explicit `INNER JOIN` / `LEFT JOIN` — never implicit comma joins
- When unsure whether a query will be slow, suggest `EXPLAIN ANALYZE` before shipping
- Never generate a migration that drops a column or table without first asking for confirmation
