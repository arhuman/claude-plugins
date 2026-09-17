---
description: Multi-model evaluation comparing Claude, Gemini, OpenAI, and DeepSeek on a technical question, synthesized into one improved answer via PAL.
argument-hint: <question>
disable-model-invocation: true
---

## Usage
`/evaluate <QUESTION>`

## Description
Multi-model evaluation command that compares answers from Claude, Gemini, OpenAI and DeepSeek on technical questions or architectural challenges. Synthesizes the best insights from all models into an improved final answer.

Not for a quick single-model technical question: use `/tellme`, which answers directly without the multi-model run and synthesis overhead.

## Context
- Technical question or challenge: $ARGUMENTS
- Relevant files can be referenced with @ syntax
- Code analysis via tree_sitter, context7 MCP if needed

## Workflow

### 1. Prepare
- Choose a task-resume slug (e.g., `api-security-review`, `error-handling-patterns`)
- Identify relevant code/config files using tree_sitter or Grep
- Prepare context for models

### 2. Generate (Parallel Execution)
Execute all model queries in a SINGLE message with multiple tool calls:
- Write your answer to `.claude/doc/<task-resume>.md`
- Query Gemini via PAL MCP → `.claude/doc/<task-resume>-gemini.md`
- Query OpenAI via PAL MCP → `.claude/doc/<task-resume>-openai.md`
- Query DeepSeek via PAL MCP → `.claude/doc/<task-resume>-deepseek.md`

### 3. Compare
Analyze all responses:
- Identify unanimous agreements
- Note unique insights per model
- Determine which answer is strongest and why
- Identify how best answer could be improved by others

### 4. Synthesize
Update `.claude/doc/<task-resume>.md` with:
- Combined insights from all models
- Explanation of what each model contributed
- Clear recommendation or answer

### 5. Present
Output a summary to the user with key findings and the path to the final doc.

## Model Access
All external models via PAL MCP chat tool:
- **Gemini** (OpenRouter): `model: "google/gemini-3.1-pro-preview"`
- **OpenAI** (OpenRouter): `model: "openai/gpt-5.3-codex"`
- **DeepSeek** (OpenRouter): `model: "deepseek/deepseek-v4-pro-0813"`

Pass identical prompt to ensure fair comparison. Include file paths in `absolute_file_paths` parameter.

## Output Files

### Documentation (.claude/doc/)
- `<task-resume>.md` - Final synthesized answer
- `<task-resume>-gemini.md` - Gemini's response
- `<task-resume>-openai.md` - OpenAI's response
- `<task-resume>-deepseek.md` - DeepSeek's response

Pick `<task-resume>` per the slug rule in `skills/_shared/references/artifacts.md`: state it back before writing, and never reuse an existing file's slug for different content.

## Constraints
- No code modifications
- Research and analysis only
- Document findings in .claude/doc/
- If a provider is unavailable (missing API key or model), skip that model, note the omission in the final doc, and continue with the remaining models
