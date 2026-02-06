# Stage 4: Quality Review

## 4.1 Review Strategy Selection

Check if `/code-review:review-local-changes` command is available by attempting to invoke it. If the command returns an error indicating it is not found or the skill is not installed, fall back to the three-agent review:

- **If available**: Use it for the review (preferred — integrates with existing review infrastructure). Normalize the output to match the finding format in Section 4.3 before consolidation.
- **If not available**: Launch 3 parallel `developer` agents, each focusing on a different quality dimension (see `config/implementation-config.yaml` for focus areas)

## 4.2 Three-Agent Review (Fallback)

Launch 3 `developer` agents in parallel using the review prompt template from `agent-prompts.md` (Section: Quality Review Prompt).

```
Task(subagent_type="product-implementation:developer")  # x3, parallel
```

### Review Dimensions

| Agent | Focus Area | What to Look For |
|-------|------------|-------------------|
| Reviewer 1 | **Simplicity / DRY / Elegance** | Duplicated code, unnecessary complexity, over-engineering, unclear naming, missing abstractions, dead code |
| Reviewer 2 | **Bugs / Functional Correctness** | Logic errors, edge cases missed, race conditions, null/undefined handling, error propagation, off-by-one errors |
| Reviewer 3 | **Project Conventions / Abstractions** | Pattern violations, inconsistent style, wrong abstractions, missing types, convention drift from CLAUDE.md/constitution.md |

### Review Scope

Each reviewer agent should:
1. Read the list of files changed during implementation (from tasks.md file paths)
2. Read each changed file
3. Compare against existing codebase patterns
4. Produce findings in structured format

## 4.3 Finding Consolidation

After all reviewers complete, consolidate findings:

### Severity Classification

Severity levels are defined in `config/implementation-config.yaml`. Summary:

| Severity | Description |
|----------|-------------|
| **Critical** | Breaks functionality, security vulnerability, data loss risk |
| **High** | Likely to cause bugs, significant code quality issue |
| **Medium** | Code smell, maintainability concern, minor pattern violation |
| **Low** | Style preference, minor optimization opportunity |

### Deduplication

- Merge findings that describe the same issue from different reviewers
- Keep the most detailed description
- Note consensus when multiple reviewers flag the same issue (higher confidence)

### Consolidation Output

```text
## Quality Review Summary

Reviewers: 3 agents (Simplicity, Correctness, Conventions)
Files reviewed: {count}
Total findings: {count}

### Critical ({count})
- [C1] Description — file:line — Reviewers: 1, 2

### High ({count})
- [H1] Description — file:line — Reviewer: 2

### Medium ({count})
- [M1] Description — file:line — Reviewer: 3

### Low ({count})
- [L1] Description — file:line — Reviewer: 1

### Recommendation
{count} issues recommended for immediate fix (Critical + High)
```

## 4.4 User Decision

Present the consolidated findings to the user via `AskUserQuestion`:

**Question:** "Quality review found {N} issues ({critical} critical, {high} high). How would you like to proceed?"

**Options:**
1. **Fix now** — Address critical and high severity issues before proceeding
2. **Fix later** — Log issues for later attention, proceed as-is
3. **Proceed as-is** — Accept current implementation without changes

### On "Fix Now"

1. Launch a `developer` agent with the fix prompt template from `agent-prompts.md` (Section: Review Fix Prompt)
2. Agent addresses Critical and High findings
3. After fixes, re-run a quick validation (tests pass, no regressions)
4. Update state file: `user_decisions.review_outcome: "fixed"`

### On "Fix Later"

1. Write findings to `{FEATURE_DIR}/review-findings.md`
2. Update state file: `user_decisions.review_outcome: "deferred"`
3. Report: "Findings saved to review-findings.md for later attention"

### On "Proceed As-Is"

1. Update state file: `user_decisions.review_outcome: "accepted"`
2. Report: "Implementation complete. Review findings acknowledged."

## 4.5 Stage Summary

After quality review is resolved, produce the stage summary and proceed to Stage 5:

```text
## Quality Review Complete

Feature: {FEATURE_NAME}
Tasks: {completed}/{total}
Phases: {completed}/{total}
Tests: All passing

Quality Review: {outcome}
- Critical issues: {count} ({resolved/deferred/accepted})
- High issues: {count} ({resolved/deferred/accepted})

Files Changed:
- {file1} — {brief description}
- {file2} — {brief description}
- ...

Proceeding to Stage 5: Feature Documentation.
```
