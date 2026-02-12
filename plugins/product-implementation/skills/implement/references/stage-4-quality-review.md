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
  - "review-findings.md (if findings exist and user chooses fix-now or fix-later)"
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

## 4.1b Research Context Resolution for Review

Build the `{research_context}` block for reviewer agent prompts using accumulated research URLs from Stage 2.

### Procedure

1. Read `mcp_availability` from the Stage 1 summary
2. Read `research_mcp` section from `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml`
3. If `research_mcp.enabled` is `false` OR all MCP tools are unavailable → set `research_context` to the fallback text and skip to Section 4.1

4. **Re-read accumulated URLs** (Ref — session accumulation):
   - Read `research_urls_discovered` from the Stage 2 summary flags
   - For each URL (up to `ref.max_reads_per_stage`): call `ref_read_url(url)` — Ref cache serves faster on re-reads from the same session
   - Cap each source at `ref.token_budgets.per_source` tokens

5. **Context7 review-specific query**:
   - Read `resolved_libraries` from Stage 1 summary
   - For each resolved library (up to `context7.max_queries_per_stage`): call `query-docs(library_id, "common pitfalls anti-patterns deprecations")`

6. **Assemble `{research_context}`**: Combine all gathered content, cap at `ref.token_budgets.research_context_total`. Include documentation-backed review dimensions:
   - **API correctness**: method signatures, parameter types from official docs
   - **Deprecation awareness**: deprecated APIs flagged in documentation
   - **Pattern compliance**: documented best practices and anti-patterns

### Context Budget

Same cap as Stage 2: `research_context_total` tokens. Re-reads benefit from Ref cache (Dropout), reducing latency.

## 4.1 Review Strategy Selection

Check if the Skill tool lists `code-review:review-local-changes` in its available skills. Query the available skills list explicitly — do NOT attempt a blind invocation to test availability.

- **If `code-review:review-local-changes` is listed**: Invoke it for the review (preferred — integrates with existing review infrastructure). Normalize the output to match the finding format in Section 4.3 before consolidation.
- **If not listed, or if invocation returns an error**: Fall back to the multi-agent review (Section 4.2). Launch 3+ parallel `developer` agents with focus areas from `config/implementation-config.yaml`.

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

### Severity Reclassification Pass

After deduplication, review each Medium-severity finding against the escalation triggers defined in `config/implementation-config.yaml` under `severity.escalation_triggers`. For each Medium finding:

1. Check if the finding matches ANY escalation trigger (user-visible data corruption, implicit ordering, UI state contradiction, singleton state leak, race condition with user-visible effect)
2. If a match is found, promote the finding from Medium to High
3. Log each promotion: "Reclassified [M{N}] → [H{N+offset}]: matches escalation trigger '{trigger}'"

This pass runs AFTER deduplication so that consensus-boosted findings are also checked. The escalation triggers are config-driven — update the config file to adjust the criteria, not this prose.

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

Before writing the summary, apply the auto-decision matrix from `config/implementation-config.yaml` under `severity.auto_decision`:

### Auto-Decision Logic

1. **No findings**: Set `status: completed`, `review_outcome: "accepted"` — no user interaction needed
2. **All findings Low only**: If `auto_accept_low_only` is `true` (default), auto-accept. Set `status: completed`, `review_outcome: "accepted"`, log: "Auto-accepted: {N} Low findings"
3. **Highest is Medium AND medium count <= `medium_auto_accept_max_count`**: Auto-accept with note. Set `status: completed`, `review_outcome: "accepted"`, log: "Auto-accepted: {N} Medium + {M} Low findings (within threshold)"
4. **Any Critical or High, OR medium count > threshold**: Escalate to user (below)

### User Escalation (Critical/High findings or excessive Medium)

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
4. **Test count cross-validation**: Compare the post-fix test count against `baseline_test_count` from the Stage 3 summary flags. If post-fix count < baseline, BLOCK: "Test count regression detected: {post_fix_count} < {baseline_test_count}. Fix agent may have broken or removed existing tests." The fix agent must resolve regressions before proceeding.
5. **Write deferred findings**: Write remaining Medium + Low findings (those NOT addressed by the fix agent) to `{FEATURE_DIR}/review-findings.md`. This ensures lower-severity findings are tracked in a dedicated artifact even when the user chose "Fix now" for Critical + High issues only.
6. **Auto-commit review fixes**: Follow the Auto-Commit Dispatch Procedure in `$CLAUDE_PLUGIN_ROOT/skills/implement/references/auto-commit-dispatch.md` with `template_key` = `review_fix`, `substitution_vars` = `{feature_name}` = FEATURE_NAME, `skip_target` = step 7, `summary_field` = `commit_sha`
7. Rewrite summary with `review_outcome: "fixed"`

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
  - "review-findings.md"  # if findings exist and outcome is fixed or deferred
  - ".implementation-state.local.md"
summary: |
  Quality review {outcome}: {count} findings ({critical} critical, {high} high).
  User decision: {fixed / deferred / accepted}.
flags:
  block_reason: null  # or consolidated findings if needs-user-input
  review_outcome: "fixed"  # fixed | deferred | accepted
  test_count_post_fix: {N}  # Verified test count after fix agent (only present when review_outcome is "fixed")
  commit_sha: null  # Auto-commit SHA after review fixes (null if disabled, skipped, or failed)
---
## Context for Next Stage

- Review outcome: {fixed / deferred / accepted}
- Critical issues: {count} ({resolved/deferred/accepted})
- High issues: {count} ({resolved/deferred/accepted})
- Files changed during review fixes: {list, if any}

## Quality Review Details

{Consolidated findings summary}
```
