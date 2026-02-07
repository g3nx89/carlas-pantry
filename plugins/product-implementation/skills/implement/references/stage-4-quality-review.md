---
stage: "4"
stage_name: "Quality Review"
checkpoint: "QUALITY_REVIEW"
delegation: "coordinator"
prior_summaries:
  - ".stage-summaries/stage-2-summary.md"
  - ".stage-summaries/stage-3-summary.md"
artifacts_read:
  - "tasks.md"
artifacts_written:
  - "review-findings.md (if user chooses fix-later)"
  - ".implementation-state.local.md"
agents:
  - "product-implementation:developer"
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/implement/references/agent-prompts.md"
  - "$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml"
  - ".stage-summaries/stage-1-summary.md (for detected_domains)"
---

# Stage 4: Quality Review

> **COORDINATOR STAGE:** This stage is dispatched by the orchestrator via `Task()`.
> Read the prior stage summaries to understand what was implemented and validated.

## 4.1a Skill Reference Resolution for Review

Before selecting the review strategy, resolve domain-specific skill references and conditional review dimensions.

### Procedure

1. Read `detected_domains` from the Stage 1 summary YAML frontmatter
2. Read `dev_skills` section from `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml`
3. If `dev_skills.enabled` is `false` or `detected_domains` is empty, set `skill_references` to fallback text and `conditional_reviewers` to empty. Skip to Section 4.1.

4. **Resolve skill references** for review agents (same algorithm as Stage 2, Section 2.0):
   - Start with `always_include`, add domain-matched skills, deduplicate, cap at `max_skills_per_dispatch`
   - Format as skill reference block

5. **Resolve conditional reviewers** from `dev_skills.conditional_review`:
   - For each entry, check if ANY of its `domains` appear in `detected_domains`
   - If matched, add its `focus` as an additional review dimension and note its `skill` for the reviewer prompt
   - Each conditional reviewer is launched as an additional `developer` agent alongside the base 3

### Output

- `skill_references`: formatted block for all review agent prompts
- `conditional_reviewers`: list of `{focus, skill}` pairs for additional reviewer dispatches

### Impact on Agent Count

Base count: 3 (from `config/implementation-config.yaml` `quality_review.agent_count`)
With conditionals: 3 + len(conditional_reviewers)

Example: For a web frontend project, `detected_domains: ["web_frontend"]` matches two conditional entries → 5 total reviewers (3 base + accessibility + web guidelines).

## 4.1 Review Strategy Selection

Check if `/code-review:review-local-changes` command is available by attempting to invoke it. If the command returns an error indicating it is not found or the skill is not installed, fall back to the three-agent review:

- **If available**: Use it for the review (preferred — integrates with existing review infrastructure). Normalize the output to match the finding format in Section 4.3 before consolidation.
- **If not available**: Launch 3 parallel `developer` agents, each focusing on a different quality dimension (see `config/implementation-config.yaml` for focus areas)

## 4.2 Multi-Agent Review (Fallback)

Launch `developer` agents in parallel using the review prompt template from `agent-prompts.md` (Section: Quality Review Prompt).

```
Task(subagent_type="product-implementation:developer")  # x3+ parallel
```

### Base Review Dimensions

| Agent | Focus Area | What to Look For |
|-------|------------|-------------------|
| Reviewer 1 | **Simplicity / DRY / Elegance** | Duplicated code, unnecessary complexity, over-engineering, unclear naming, missing abstractions, dead code |
| Reviewer 2 | **Bugs / Functional Correctness** | Logic errors, edge cases missed, race conditions, null/undefined handling, error propagation, off-by-one errors |
| Reviewer 3 | **Project Conventions / Abstractions** | Pattern violations, inconsistent style, wrong abstractions, missing types, convention drift from CLAUDE.md/constitution.md |

### Conditional Review Dimensions

If `conditional_reviewers` was populated in Section 4.1a, launch additional `developer` agents — one per conditional entry — using the same review prompt template but with:
- `{focus_area}` set to the conditional entry's `focus` value
- `{skill_references}` including the conditional entry's `skill` path (the reviewer should consult this skill for domain-specific review criteria)

Example conditional reviewers:

| Agent | Focus Area | Triggered By | Skill Reference |
|-------|------------|-------------|-----------------|
| Reviewer 4 | **Accessibility / WCAG 2.1 AA** | `web_frontend`, `compose`, `android` in `detected_domains` | `accessibility-auditor` |
| Reviewer 5 | **Web Best Practices / Performance** | `web_frontend` in `detected_domains` | `web-design-guidelines` |

All conditional reviewers run in parallel with the base 3.

### Review Scope

Each reviewer agent should:
1. Read the list of files changed during implementation (from tasks.md file paths)
2. Read each changed file
3. Compare against existing codebase patterns
4. If skill references are provided, consult them for domain-specific review criteria
5. Produce findings in structured format

## 4.3 Finding Consolidation

After all reviewers complete, consolidate findings:

### Severity Classification

Use the canonical severity levels defined in SKILL.md and `config/implementation-config.yaml`: Critical, High, Medium, Low.

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

Set `status: needs-user-input` in the stage summary with the consolidated findings as the `block_reason`. The orchestrator will present options to the user:

**Question:** "Quality review found {N} issues ({critical} critical, {high} high). How would you like to proceed?"

**Options:**
1. **Fix now** — Address critical and high severity issues before proceeding
2. **Fix later** — Log issues for later attention, proceed as-is
3. **Proceed as-is** — Accept current implementation without changes

**Important:** The coordinator does NOT interact with the user directly. Write the summary and let the orchestrator relay the interaction.

If orchestrator provides a user-input file:
- Read `{FEATURE_DIR}/.stage-summaries/stage-4-user-input.md`
- Execute the chosen option (see below)

### On "Fix Now"

1. Launch a `developer` agent with the fix prompt template from `agent-prompts.md` (Section: Review Fix Prompt)
2. Agent addresses Critical and High findings
3. After fixes, re-run a quick validation (tests pass, no regressions)
4. Rewrite summary with `review_outcome: "fixed"`

### On "Fix Later"

1. Write findings to `{FEATURE_DIR}/review-findings.md`
2. Set `review_outcome: "deferred"` in summary

### On "Proceed As-Is"

1. Set `review_outcome: "accepted"` in summary

## 4.5 Write Stage 4 Summary

Write summary to `{FEATURE_DIR}/.stage-summaries/stage-4-summary.md`:

```yaml
---
stage: "4"
stage_name: "Quality Review"
checkpoint: "QUALITY_REVIEW"
status: "completed"  # or "needs-user-input" initially
artifacts_written:
  - "review-findings.md"  # only if deferred
  - ".implementation-state.local.md"
summary: |
  Quality review {outcome}: {count} findings ({critical} critical, {high} high).
  User decision: {fixed / deferred / accepted}.
flags:
  block_reason: null  # or consolidated findings if needs-user-input
  review_outcome: "fixed"  # fixed | deferred | accepted
---
## Context for Next Stage

- Review outcome: {fixed / deferred / accepted}
- Critical issues: {count} ({resolved/deferred/accepted})
- High issues: {count} ({resolved/deferred/accepted})
- Files changed during review fixes: {list, if any}

## Quality Review Details

{Consolidated findings summary}
```
