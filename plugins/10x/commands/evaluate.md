## Usage
`/evaluate <QUESTION>`

## Description
Multi-model evaluation command that compares answers from Claude, Gemini, Mistral, and Qwen on technical questions or architectural challenges. Synthesizes the best insights from all models into an improved final answer.

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
- Query Mistral via PAL MCP → `.claude/doc/<task-resume>-mistral.md`
- Query Qwen via PAL MCP → `.claude/doc/<task-resume>-qwen.md`

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
- **Gemini**: `model: "google/gemini-2.5-pro"`
- **Mistral**: `model: "local-mistral"`
- **Qwen**: `model: "local-qwen"`

Pass identical prompt to ensure fair comparison. Include file paths in `absolute_file_paths` parameter.

## Output Files

### Documentation (.claude/doc/)
- `<task-resume>.md` - Final synthesized answer
- `<task-resume>-gemini.md` - Gemini's response
- `<task-resume>-mistral.md` - Mistral's response
- `<task-resume>-qwen.md` - Qwen's response

## Constraints
- No code modifications
- Research and analysis only
- Document findings in .claude/doc/
