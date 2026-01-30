## Usage
`/tellme <QUESTION>`

## Description
Technical Q&A command for architectural guidance, code analysis, and technology decisions. Provides expert consultation using available tools and knowledge without modifying code.

## Context
- Technical question or challenge: $ARGUMENTS
- Files can be referenced with @ syntax
- Current system constraints and business context considered

## Question Types and Tool Selection

### Code Structure Questions
"What does function X do?" / "Where is Y implemented?" / "How does Z work?"

**Tools:**
1. tree_sitter MCP - Find definitions, implementations, call sites
2. Grep/rg - Search for patterns and usage
3. Read - Examine specific files

**Optional**: Delegate to coder-agent for complex analysis

### Library/Framework Questions
"How does library X work?" / "What's the syntax for Y?" / "Is feature Z available?"

**Tools:**
1. Context7 MCP - Resolve library ID and fetch docs
2. WebSearch - For recent updates or migration guides

### Architecture/Design Questions
"Should we use X or Y?" / "What's the best approach for Z?" / "How to structure W?"

**Tools:**
1. PAL MCP chat - Single model quick answer
2. PAL MCP consensus - Multi-model for important decisions
3. tree_sitter - Analyze existing patterns

**Optional**: Delegate to coder-agent for Go-specific architecture

### Performance/Security Questions
"Is this code secure?" / "Will this scale?" / "What are the bottlenecks?"

**Tools:**
1. tree_sitter - Analyze complexity and structure
2. PAL MCP thinkdeep - Systematic investigation
3. Delegate to review-agent for comprehensive review

## Workflow

### 1. Classify Question
Determine question type and select appropriate tools.

### 2. Gather Context
- Use tree_sitter for code structure understanding
- Use Grep/rg for finding relevant code sections
- Read identified files for detailed analysis

### 3. Research
Execute tool queries:
- Context7 for library docs
- PAL MCP for architectural insights
- tree_sitter for code relationships

### 4. Analyze
Synthesize information:
- Explain the "what" and "why"
- Provide alternatives when applicable
- Consider trade-offs and constraints

### 5. Answer
Deliver response with:
- Direct answer to the question
- Supporting evidence and examples
- Alternatives or considerations
- Relevant file references (file:line format)

## Output Format

**For "what/where/how" questions:**
- Clear explanation of current state
- File references with line numbers
- Code examples if helpful

**For "should/best" questions:**
- Recommendation with rationale
- Alternatives with pros/cons
- Trade-offs and implications
- Examples from similar situations

**For "will/can" questions:**
- Assessment based on analysis
- Supporting evidence
- Potential issues or considerations
- Suggestions for validation

## Constraints
- No code modifications
- Consultation and analysis only
- Document findings in response, not in files (unless requested)

## Examples

`/tellme What does the authentication middleware do?`
→ Use tree_sitter to find middleware, Read to examine, explain functionality

`/tellme Should we use PostgreSQL or MongoDB for user data?`
→ Use PAL MCP consensus for multi-perspective analysis, provide recommendation

`/tellme How to implement rate limiting in Go?`
→ Context7 for Go rate limiting libraries, provide examples and recommendations

`/tellme Where is the user validation logic?`
→ Grep for "validation" patterns, tree_sitter for structure, provide file locations
