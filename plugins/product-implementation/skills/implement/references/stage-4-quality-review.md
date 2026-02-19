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
  - "$CLAUDE_PLUGIN_ROOT/skills/implement/references/cli-dispatch-procedure.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/implement/references/stage-4-plugin-review.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/implement/references/stage-4-cli-review.md"
  - "$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml"
  - ".stage-summaries/stage-1-summary.md (for detected_domains, cli_availability)"
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

## 4.1 Three-Tier Review Architecture

Stage 4 uses a layered review approach. All tiers that are available run in parallel, and their findings are merged in Section 4.3.

| Tier | Source | When It Runs | Details |
|------|--------|-------------|---------|
| **A: Native** | Claude Code `developer` agents (3+ parallel) | Always | Section 4.2 below |
| **B: Plugin** | `code-review:review-local-changes` skill | When plugin installed | See `stage-4-plugin-review.md` |
| **C: CLI** | Codex + Gemini external CLIs | When `cli_dispatch.stage4.multi_model_review.enabled` is `true` | See `stage-4-cli-review.md` |

**Dispatch order:** All available tiers launch in parallel. The coordinator dispatches Tier A and Tier C reviewers directly. Tier B is dispatched via a context-isolated subagent (see `stage-4-plugin-review.md`). After all tiers complete, findings merge in Section 4.3 with confidence scoring and deduplication.

## 4.2 Tier A: Native Multi-Agent Review

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

## 4.2a Tier B: Plugin Review

> See `stage-4-plugin-review.md` for the full procedure.

When the `code-review` plugin is installed, Tier B runs a context-isolated review via `code-review:review-local-changes`. Findings are normalized to match the Stage 4 severity format and fed into Section 4.3 consolidation. If the plugin is not installed, Tier B is silently skipped.

## 4.2b Tier C: CLI Multi-Model Review

> See `stage-4-cli-review.md` for the full procedure.

When `cli_dispatch.stage4.multi_model_review.enabled` is `true`, Tier C dispatches external CLI agents for multi-model review. Phase 1 runs parallel reviewers (correctness via Codex, plus conditional security and Android domain reviewers). Phase 2 conditionally runs a codebase-wide pattern search via Gemini when Phase 1 produces Critical/High findings. All CLI dispatches follow `cli-dispatch-procedure.md`.

### Dev-Skills Conditional Reviewers

Conditional reviewers from `dev_skills.conditional_review` (Section 4.1a) launch alongside all tiers. They are always dispatched as native `developer` agents.

## 4.3 Finding Consolidation

After all reviewers complete, consolidate findings:

### Severity Classification

Use the canonical severity levels defined in SKILL.md and `config/implementation-config.yaml`: Critical, High, Medium, Low.

### Confidence Scoring

Before deduplication, assign a confidence score to each finding. Read `cli_dispatch.stage4.confidence_scoring` from config:

| Factor | Points | Condition |
|--------|--------|-----------|
| Base | 40 | Every finding starts here |
| Consensus | +25 | 2+ tiers flagged the same issue (same file:line or semantically equivalent) |
| File:line reference | +15 | Finding includes exact file path and line number |
| Code snippet | +10 | Finding includes a code excerpt demonstrating the issue |
| Known pattern | +10 | Finding matches a known anti-pattern from escalation triggers or skill references |

**Progressive threshold filtering** — after scoring, apply minimum confidence thresholds from `confidence_scoring.thresholds`:
- Critical findings: retain if score >= 50
- High findings: retain if score >= 65
- Medium findings: retain if score >= 75
- Low findings: retain if score >= 90

Findings below their threshold are demoted one severity level (Medium → Low, Low → dropped). This filters low-confidence noise while preserving high-confidence findings at every severity.

### Deduplication

- Merge findings that describe the same issue from different tiers/reviewers
- Keep the most detailed description
- Apply consensus bonus when multiple sources flag the same issue

### Severity Reclassification Pass

After deduplication, review each Medium-severity finding against the escalation triggers defined in `config/implementation-config.yaml` under `severity.escalation_triggers`. For each Medium finding:

1. Check if the finding matches ANY escalation trigger (user-visible data corruption, implicit ordering, UI state contradiction, singleton state leak, race condition with user-visible effect)
2. If a match is found, promote the finding from Medium to High
3. Log each promotion: "Reclassified [M{N}] → [H{N+offset}]: matches escalation trigger '{trigger}'"

This pass runs AFTER deduplication so that consensus-boosted findings are also checked. The escalation triggers are config-driven — update the config file to adjust the criteria, not this prose.

> **Note:** Findings promoted by escalation triggers intentionally bypass the confidence threshold for their new severity level. A Medium finding at score 75 promoted to High (threshold 65) is retained without re-filtering. This is by design — escalation triggers represent domain knowledge that overrides statistical confidence.

### Consolidation Output

```text
## Quality Review Summary

Reviewers: {count} sources (Tier A: native, Tier B: plugin, Tier C: CLI)
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

Before writing the summary, apply the auto-decision matrix. The autonomy policy from Stage 1 summary EXTENDS the base auto-decision matrix — it does not replace it. The base matrix handles the "no findings" and "low-only" cases that are always auto-accepted. The autonomy policy handles the cases that would otherwise escalate to the user.

### Auto-Decision Logic (Base Matrix)

Read `severity.auto_decision` from `config/implementation-config.yaml`:

1. **No findings**: Set `status: completed`, `review_outcome: "accepted"` — no user interaction needed
2. **All findings Low only**: If `auto_accept_low_only` is `true` (default), auto-accept. Set `status: completed`, `review_outcome: "accepted"`, log: "Auto-accepted: {N} Low findings"
3. **Highest is Medium AND medium count <= `medium_auto_accept_max_count`**: Auto-accept with note. Set `status: completed`, `review_outcome: "accepted"`, log: "Auto-accepted: {N} Medium + {M} Low findings (within threshold)"
4. **Any Critical or High, OR medium count > threshold**: Check autonomy policy (below)

### Autonomy Policy Check (extends base matrix)

Read `autonomy_policy` from the Stage 1 summary. Read the policy level definition from `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml` under `autonomy_policy.levels.{policy}`.

For each severity level present in findings (Critical, High, Medium), look up `policy.findings.{severity}`:
- **`"fix"`**: Add to the auto-fix list
- **`"defer"`**: Add to the defer list (will be written to `review-findings.md`)
- **`"accept"`**: Accept silently

Then apply:
- If auto-fix list is non-empty: Auto-fix — launch fix agent (Option F CLI or native developer) for findings in the fix list. Log: `"[AUTO-{policy}] Auto-fixing {N} findings ({severity_breakdown})"`. After fix, run test count cross-validation (same as manual "Fix now"). Write deferred findings to `review-findings.md`. Set `review_outcome: "fixed"`.
- If auto-fix list is empty but defer list is non-empty: Write defer list to `review-findings.md`. Log: `"[AUTO-{policy}] Deferred {N} findings"`. Set `review_outcome: "deferred"`.
- If both lists are empty (all accepted): Set `review_outcome: "accepted"`. Log: `"[AUTO-{policy}] All findings accepted"`.
- If no policy set (edge case): fall through to manual escalation below.

### Manual Escalation (when no autonomy policy applies)

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

#### Option F: CLI Fix Engineer

> **Conditional**: When `cli_dispatch.stage4.fix_engineer.enabled` is `true` AND `cli_availability.codex` is `true` (from Stage 1 summary), use the CLI fix engineer instead of the native developer agent. If conditions are not met, use the native path below.

**CLI fix path:**
1. Build prompt from `$CLAUDE_PLUGIN_ROOT/config/cli_clients/codex_fix_engineer.txt`. Inject variables:
   - `{findings_list}` — Critical + High findings from consolidated review
   - `{baseline_test_count}` — from Stage 3 summary `flags.baseline_test_count`
   - `{FEATURE_DIR}`, `{TASKS_FILE}` — from Stage 1 summary
2. Dispatch via Shared CLI Dispatch Procedure (`cli-dispatch-procedure.md`) with:
   - `cli_name="codex"`, `role="fix_engineer"`
   - `file_paths=[...files_with_findings]`
   - `fallback_behavior="native"`, `fallback_agent="product-implementation:developer"`, `fallback_prompt=` Review Fix Prompt from `agent-prompts.md`
   - `expected_fields=["findings", "tests", "regression", "patterns_fixed"]`
3. Parse `test_count_post_fix` from output (regex: `test_count_post_fix:\s*(\d+)`)
4. **Write boundaries**: The CLI agent may only modify files listed in the findings. Verify no other files were changed.
5. If CLI fails, regression detected, or parsing fails → fall back to native developer agent (below)

**Native fix path** (default, or fallback from CLI):
1. Launch a `developer` agent with the fix prompt template from `agent-prompts.md` (Section: Review Fix Prompt)
2. Agent addresses Critical and High findings

**Common steps (both paths):**
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
  confidence_scoring_stats: null  # null if confidence scoring disabled or single-tier only. When multi-tier:
    # findings_before_scoring: {N}   — Raw finding count before confidence filtering
    # findings_after_scoring: {N}    — Finding count after progressive threshold filtering
    # findings_demoted: {N}          — Findings demoted one severity level
    # findings_dropped: {N}          — Low findings dropped (below threshold)
    # consensus_matches: {N}         — Findings with 2+ tier agreement (received consensus bonus)
    # score_distribution: {min: N, max: N, median: N}  — Score range across all findings
---
## Context for Next Stage

- Review outcome: {fixed / deferred / accepted}
- Critical issues: {count} ({resolved/deferred/accepted})
- High issues: {count} ({resolved/deferred/accepted})
- Files changed during review fixes: {list, if any}

## Quality Review Details

{Consolidated findings summary}
```
