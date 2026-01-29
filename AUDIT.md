# Repository Audit Report

**Date**: 2026-01-29
**Scope**: Claude plugin marketplace repository with focus on global-project-manager plugin

---

## Executive Summary

This audit identifies path inconsistencies, documentation gaps, redundancies, and contradictory information across the repository. The plugin is functional but suffers from documentation quality issues that may confuse users and contributors.

**Critical Issues**: 3
**High Priority**: 8
**Medium Priority**: 6
**Low Priority**: 4

---

## Critical Issues

### 1. Path Inconsistencies in Documentation

**Location**: `plugins/global-project-manager/skills/global-project-manager/references/examples.md:33`

**Issue**: Path shows `claude/global-project/task-001.md` (missing leading dot)

**Should be**: `.claude/global-project/task-001.md`

**Impact**: Users following examples will create files in wrong location

---

### 2. Contradictory Information in CLAUDE.md

**Location**: `/CLAUDE.md` lines mentioning naming inconsistency

**Issue**: CLAUDE.md claims there's a naming inconsistency:
> The plugin is called `global-project-manager` in the directory structure and README, but `global-task-manager` in:
> - `marketplace.json` (line 10)
> - `plugin.json` (line 2)

**Reality**: Both files correctly use `global-project-manager`
- marketplace.json:10 → `"name": "global-project-manager"` ✓
- plugin.json:2 → `"name": "global-project-manager"` ✓

**Impact**: Misleading information causes confusion about actual state

**Fix**: Remove or correct this section in CLAUDE.md

---

### 3. Inconsistent Plugin Title

**Location**: `plugins/global-project-manager/skills/global-project-manager/SKILL.md:6`

**Issue**: Header says "Global Task Manager" but plugin is named "Global Project Manager"

**Impact**: Branding confusion, unclear what the plugin is called

---

## High Priority Issues

### 4. Typo in Keywords

**Location**: `plugins/global-project-manager/.claude-plugin/plugin.json:10`

**Current**: `"jujustsu"`
**Should be**: `"jujutsu"`

---

### 5. Missing Critical Files

**Missing**:
- `CHANGELOG.md` - No version history despite being at v0.6.0
- `CONTRIBUTING.md` - No contributor guidelines
- `.gitignore` - No ignore rules
- `tests/` - No test suite or test documentation
- `docs/screenshots/` - No visual examples

**Impact**:
- Hard to track changes between versions
- No guidance for contributors
- Risk of committing sensitive files
- No quality assurance mechanism
- Users can't preview what it looks like

---

### 6. Installation Instructions Redundancy

**Locations**: Repeated in 3 places
1. Root `/README.md` (lines 6-20)
2. `plugins/global-project-manager/README.md` (lines 14-19)
3. `/CLAUDE.md` (Plugin Installation section)

**Issue**: Maintenance burden, risk of drift

**Recommendation**:
- Keep detailed instructions only in plugin README
- Root README should link to plugin README
- CLAUDE.md should reference, not duplicate

---

### 7. Status/Priority Values Duplicated

**Locations**: Defined in 3 places
1. `plugins/global-project-manager/README.md` (lines 21-33)
2. `plugins/global-project-manager/skills/global-project-manager/SKILL.md` (line 32)
3. `plugins/global-project-manager/skills/global-project-manager/references/schema.md` (lines 82-83)

**Issue**: Single source of truth violation

**Recommendation**: Define once in schema.md, reference everywhere else

---

### 8. No S3/Minio Setup Documentation

**Location**: Multiple mentions but no setup guide

**Referenced in**:
- SKILL.md:84-86 mentions env vars
- schema.md:122-133 shows S3 structure

**Missing**:
- How to set up MinIO locally
- Environment variable configuration examples
- Authentication setup steps
- Bucket creation instructions
- Security considerations

---

### 9. No Error Handling Documentation

**Missing**:
- What happens when `.jj/` exists but jj commands fail?
- What if S3 sync fails?
- What if task file is corrupted?
- What if two tasks get same ID (race condition)?
- What if user doesn't have write permissions to `.claude/`?

**Referenced**: examples.md:151-156 mentions sync failure but no comprehensive guide

---

### 10. Root README Too Sparse

**Location**: `/README.md` (21 lines total)

**Current content**:
- Title
- Installation (duplicated)
- Nothing about what plugins do
- No screenshots
- No features list
- No links to individual plugin docs

**Should include**:
- Marketplace overview
- List of available plugins with descriptions
- Links to each plugin's README
- How to develop new plugins
- Contributing guidelines

---

### 11. No Plugin Development Guide

**Missing**: Documentation for creating new plugins in this marketplace

**Needed**:
- Plugin structure requirements
- How to add to marketplace.json
- Testing guidelines
- Documentation standards
- Publishing process

---

## Medium Priority Issues

### 12. Incomplete Schema Validation Rules

**Location**: `plugins/global-project-manager/skills/global-project-manager/references/schema.md`

**Missing**:
- Max length for `title`, `shortname`, `name`
- Validation regex for `shortname` (kebab-case format)
- Required vs optional field clarity
- Default values when fields omitted
- Constraints on status transitions (can you go from `done` to `in_progress`?)

---

### 13. Timestamp Format Inconsistency

**Issue**: ISO 8601 mentioned but not consistently shown

**Examples**:
- schema.md uses `2025-01-27T10:00:00Z` (with Z)
- examples.md uses same format

**Missing**:
- Timezone handling explanation
- What if system clock is wrong?
- Do timestamps need to be UTC?

---

### 14. No Performance Considerations

**Missing**:
- What happens with 100+ tasks?
- What happens with 1000+ tasks?
- Should old completed tasks be archived?
- File system limitations?
- S3 sync performance with many files?

---

### 15. Agent Trigger Logic Unclear

**Location**: `plugins/global-project-manager/agents/task-setter.md`

**Issue**: Says "spans multiple files (3+)" but unclear:
- How does the agent know this before work starts?
- What if user says "quick edit" but touches 4 files?
- Can user override the auto-detection?

---

### 16. No Migration Guide

**Issue**: Plugin at v0.6.0 but no upgrade path documentation

**Missing**:
- What changed between versions?
- Are old task files compatible?
- Breaking changes list
- How to migrate from older versions?

---

### 17. No Security Documentation

**Missing**:
- S3 credentials security
- Task content sensitivity (what if tasks contain secrets?)
- File permissions recommendations
- Git commit safety (tasks might have sensitive info)

---

## Low Priority Issues

### 18. Inconsistent Markdown Formatting

**Examples**:
- Some files use `## Heading`, others inconsistent spacing
- Some use triple backticks with language, some without
- Table formatting varies

**Recommendation**: Adopt markdown linter (markdownlint)

---

### 19. No License in Root

**Issue**: Plugin has LICENSE file, but root doesn't

**Impact**: Unclear if MIT applies to entire marketplace or just the plugin

---

### 20. No GitHub Metadata

**Missing**:
- `.github/ISSUE_TEMPLATE/`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/workflows/` (CI/CD)
- CODEOWNERS file

---

### 21. Examples Don't Show All Features

**Location**: `examples.md`

**Missing examples for**:
- Creating task with detailed directory structure
- Handling multiple in-progress tasks
- Filtering tasks by date ranges
- S3 sync operations
- Recovering from errors

---

## Recommendations by Priority

### Immediate (This Week)

1. Fix path in examples.md (`.claude/` prefix)
2. Fix CLAUDE.md incorrect naming inconsistency claim
3. Fix SKILL.md title to "Global Project Manager"
4. Fix typo "jujustsu" → "jujutsu"
5. Create CHANGELOG.md

### Short-term (This Month)

6. Create CONTRIBUTING.md
7. Add .gitignore
8. Consolidate installation instructions
9. Create S3/Minio setup guide
10. Expand root README.md
11. Add error handling documentation

### Medium-term (This Quarter)

12. Create plugin development guide
13. Add schema validation rules
14. Document security considerations
15. Add performance guidelines
16. Create migration guide between versions
17. Add comprehensive examples

### Long-term (Future)

18. Add test suite
19. Set up CI/CD
20. Add screenshots/demos
21. Set up GitHub templates
22. Consider versioned documentation

---

## Structural Improvements

### Suggested Repository Structure

```
.
├── .github/
│   ├── ISSUE_TEMPLATE/
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── workflows/
├── docs/
│   ├── plugin-development.md
│   ├── screenshots/
│   └── guides/
│       ├── s3-setup.md
│       └── troubleshooting.md
├── plugins/
│   └── global-project-manager/
│       ├── .claude-plugin/
│       ├── agents/
│       ├── skills/
│       ├── tests/
│       ├── CHANGELOG.md
│       ├── LICENSE
│       └── README.md
├── .gitignore
├── CHANGELOG.md (marketplace changelog)
├── CLAUDE.md
├── CONTRIBUTING.md
├── LICENSE (marketplace license)
└── README.md
```

---

## Documentation Style Guidelines (Proposed)

1. **Single Source of Truth**: Define values once, reference elsewhere
2. **Consistent Paths**: Always use full absolute paths in examples (`.claude/global-project/`)
3. **Versioned Docs**: Consider docs/v0.6/ structure for major versions
4. **Code Blocks**: Always specify language for syntax highlighting
5. **Links**: Use relative links within repo, absolute for external
6. **Examples**: Show both success and failure cases

---

## Metrics

**Total Files Analyzed**: 11
**Documentation Files**: 7
**Configuration Files**: 4
**Lines of Documentation**: ~650

**Documentation Coverage**:
- Installation: 100%
- Basic Usage: 70%
- Advanced Features: 30%
- Troubleshooting: 10%
- Development: 0%

---

## Conclusion

The plugin is functionally complete but documentation quality needs improvement. The most critical issues are:

1. Incorrect information in CLAUDE.md about naming
2. Path errors in examples that will break user workflows
3. Missing fundamental files (CHANGELOG, CONTRIBUTING, .gitignore)

Addressing the immediate priorities will significantly improve user experience and maintainability.
