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
  - ".stage-summaries/stage-1-summary.md (for detected_domains, cli_availability, vertical_agent_type, features)"
---

# Stage 4: Quality Review

> **COORDINATOR STAGE:** This stage is dispatched by the orchestrator via `Task()`.
> Read the prior stage summaries to understand what was implemented and validated.
> **CLI dispatch: ONLY use `dispatch-cli-agent.sh`**: For ALL Tier C CLI dispatches (correctness, security, domain, UX reviewers), use `$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh` via Bash(). NEVER use the `ask` command or CCB async dispatch — the async queue returns stale cross-stage results.

## Phase Scope Mode

When the coordinator prompt includes a `## Phase Scope` block, this stage reviews ONLY the specified phase's modified files:
- **Review scope**: only files modified in this phase (from the phase's Stage 2 summary or git diff)
- **Summary path**: write to the path specified in the Phase Scope block (e.g., `phase-{N}-stage-4-summary.md`)
- **Prior summaries**: read `phase-{N}-stage-2-summary.md` and `phase-{N}-stage-3-summary.md`
- **Tier A (native reviewers)**: always runs per-phase — code quality review applies to all domains
- **Figma parity gate**: only for phases with UI tasks AND `figma_available: true` (from Stage 1 summary). Call `figma_check_design_parity` after reviewing UI components.
- **Tier B (plugin review)**: final pass only (never per-phase)
- **Tier C (CLI multi-model)**: final pass only (never per-phase)

When NO Phase Scope is present, this is a **full-project review** (final pass). All tiers run across the entire implementation. Summary path: `final-stage-4-summary.md` or `stage-4-summary.md`.

## 4.0 Feature Interaction Matrix

When multiple optional features are enabled (stances, convergence, confidence scoring, CoVe), they interact. This matrix shows processing order and pairwise interactions.

**Processing order:** Stances → Review → Convergence → Confidence Scoring → Deduplication → Escalation → Stance Divergence → CoVe

| Feature A | Feature B | Interaction | Handling |
|-----------|-----------|-------------|----------|
| Stances | Convergence | Stance-biased vocabulary can depress Jaccard scores | Convergence limitations note acknowledges this; no correction applied |
| Stances | Confidence | Stance agreement adds consensus bonus | Finding flagged by advocate + challenger both = stronger signal |
| Convergence | Confidence | Convergence strategy affects dedup before confidence scoring | HIGH convergence → standard dedup; LOW → present all (confidence scores still apply) |
| Convergence | CoVe | Low convergence increases noise → more CoVe work | CoVe min_findings_trigger gates unnecessary verification |
| Confidence | CoVe | Confidence filters before CoVe runs | CoVe only verifies findings that survived confidence thresholds |
| Stances | CoVe | Divergent-stance findings may need more verification | CoVe treats all Critical/High equally regardless of stance origin |

## 4.1a Conditional Reviewer Resolution

Before selecting the review strategy, resolve conditional review dimensions based on detected domains.

### Procedure

1. Read `detected_domains` from the Stage 1 summary YAML frontmatter
2. If `detected_domains` is empty, set `conditional_reviewers` to empty. Skip to Section 4.1.

3. **Resolve conditional reviewers** using these inline definitions (from `dev_skills.conditional_review`):
   - `web_frontend` in `detected_domains` → add reviewer: focus `"Accessibility / WCAG 2.1 AA — interactive element roles, keyboard navigation, color contrast, ARIA labels"`
   - `web_frontend` in `detected_domains` → add reviewer: focus `"Web Best Practices / Performance — bundle size, render blocking, lighthouse score, caching headers"`
   - `compose` or `android` in `detected_domains` → add reviewer: focus `"Android Accessibility / TalkBack — content descriptions, touch target sizes, semantic roles"`
   - Each conditional reviewer is launched as an additional `developer` agent alongside the base 3
   - Cap at 2 conditional reviewers total

### Output

- `conditional_reviewers`: list of `{focus}` values for additional reviewer dispatches

### Impact on Agent Count

Base count: 3 (inline default — `quality_review.agent_count`)
With conditionals: 3 + len(conditional_reviewers)

Example: For a web frontend project, `detected_domains: ["web_frontend"]` matches two conditional entries → 5 total reviewers (3 base + accessibility + web guidelines).

## 4.1b Research Context Resolution for Review

Build the `{research_context}` block for reviewer agent prompts using accumulated research URLs from Stage 2.

### Procedure

1. Read `mcp_availability` from the Stage 1 summary
2. Read `features.research_mcp` from the Stage 1 summary
3. If `features.research_mcp` is `false` OR all MCP tools are unavailable → set `research_context` to `"No research context available — proceed with codebase knowledge and planning artifacts only."` and skip to Section 4.1

4. **Re-read accumulated URLs** (Ref — session accumulation):
   - Read `research_urls_discovered` from the Stage 2 summary flags
   - For each URL (up to 5): call `ref_read_url(url)` — Ref cache serves faster on re-reads from the same session
   - Cap each source at 2000 tokens

5. **Context7 review-specific query**:
   - Read `resolved_libraries` from Stage 1 summary
   - For each resolved library (up to 3): call `query-docs(library_id, "common pitfalls anti-patterns deprecations")`

6. **Assemble `{research_context}`**: Combine all gathered content, cap at 4000 tokens. Include documentation-backed review dimensions:
   - **API correctness**: method signatures, parameter types from official docs
   - **Deprecation awareness**: deprecated APIs flagged in documentation
   - **Pattern compliance**: documented best practices and anti-patterns

### Context Budget

Capped at 4000 tokens. Re-reads benefit from Ref cache (Dropout), reducing latency.

## 4.1 Three-Tier Review Architecture

Stage 4 uses a layered review approach. All tiers that are available run in parallel, and their findings are merged in Section 4.3.

| Tier | Source | When It Runs | Details |
|------|--------|-------------|---------|
| **A: Native** | Claude Code `developer` agents (3+ parallel) | Always | Section 4.2 below |
| **B: Plugin** | `code-review:review-local-changes` skill | When plugin installed | See `stage-4-plugin-review.md` |
| **C: CLI** | Codex + Gemini external CLIs | When `cli_features_enabled.multi_model_review` is `true` (from Stage 1 summary) | See `stage-4-cli-review.md` |

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

Example conditional reviewers:

| Agent | Focus Area | Triggered By |
|-------|------------|-------------|
| Reviewer 4 | **Accessibility / WCAG 2.1 AA** | `web_frontend`, `compose`, `android` in `detected_domains` |
| Reviewer 5 | **Web Best Practices / Performance** | `web_frontend` in `detected_domains` |

All conditional reviewers run in parallel with the base 3.

### Stance Assignment (Optional)

> Conditional: Only when `features.stances` is `true` (from Stage 1 summary).
> If disabled, set `{reviewer_stance}` to `"No specific stance assigned — review objectively using your best judgment."` for all reviewers.

Assign inline stances to the 3 base reviewers:

| Reviewer | Focus | Stance | Prompt Extension |
|----------|-------|--------|-----------------|
| 1 | Simplicity/DRY | `advocate` | "You are an advocate — look for strengths, elegant solutions, and what the developer did well. Flag only genuine issues." |
| 2 | Bugs/Correctness | `challenger` | "You are a challenger — actively probe for weaknesses, edge cases, and failure modes. Assume bugs until proven otherwise." |
| 3 | Conventions/Patterns | `neutral` | "You are a neutral observer — evaluate objectively against project conventions without bias toward praise or criticism." |

Format `{reviewer_stance}` for each reviewer:
```
Your review stance: **{stance_name}**. {prompt_extension}
```

Conditional reviewers (from Section 4.1a) and Tier B/C reviewers always receive empty `{reviewer_stance}` (neutral behavior).

### Review Scope

Each reviewer agent should:
1. Read the list of files changed during implementation (from tasks.md file paths)
2. Read each changed file
3. Compare against existing codebase patterns
4. If skill references are provided, consult them for domain-specific review criteria
5. Produce findings in structured format

## 4.2a Tier B: Plugin Review

> See `stage-4-plugin-review.md` for the full procedure.

When the `code-review` plugin is installed, Tier B runs a context-isolated review via `code-review:review-local-changes`. The subagent prompt includes `detected_domains` and tech stack from Stage 1 summary to enable domain-aware review heuristics. Findings are normalized to match the Stage 4 severity format and fed into Section 4.3 consolidation. If the plugin is not installed, Tier B is silently skipped.

## 4.2b Tier C: CLI Multi-Model Review

> See `stage-4-cli-review.md` for the full procedure.

When `"multi_model_review"` is in `cli_features_enabled` (from Stage 1 summary), Tier C dispatches external CLI agents for multi-model review. Phase 1 runs parallel reviewers (correctness via Codex, plus conditional security, Android domain, and UX/accessibility reviewers). Phase 2 conditionally runs a codebase-wide pattern search via Gemini when Phase 1 produces Critical/High findings. All CLI dispatches follow `cli-dispatch-procedure.md`.

### Dev-Skills Conditional Reviewers

Conditional reviewers from `config/profile-definitions.yaml` conditional_reviewers (Section 4.1a) launch alongside all tiers. They are always dispatched as native `developer` agents.

### Native Agent Failure Tracking

Track consecutive `developer` agent failures (crash, timeout, empty output) across all dispatches in this stage. If failures reach 3 (inline default: `native_agent_failure_threshold=3`), surface diagnostic: "Consecutive native agent failures ({N}) — check agent prompt complexity, context size, or model availability." This mirrors the CLI circuit breaker pattern but for native agents.

## 4.3a Convergence Detection (Optional)

> Conditional: Only when `features.convergence` is `true` (from Stage 1 summary) AND >= 2 reviewers completed.
> If disabled or single reviewer, skip to Section 4.3 with default strategy `"standard_merge_deduplicate"`.

After all reviewers complete (Tiers A + optionally B + C), measure inter-reviewer agreement:

### Procedure

1. Collect all reviewer outputs as `{reviewer_id, findings_text}` pairs
2. Extract top 20 technical keywords from each (inline default: `keyword_count=20`):
   - Tokenize, filter stop words and generic review terms ("issue", "finding", "code", "file")
   - Keep technical terms (class names, method names, patterns, framework terms)
   - Select top N by frequency
3. Compute pairwise Jaccard similarity: `|A intersect B| / |A union B|`
4. Average all pairwise scores
5. Classify (inline thresholds: `high=0.70`, `medium=0.40`):
   - `avg >= 0.70`: HIGH — use strategy `standard_merge_deduplicate`
   - `avg >= 0.40`: MEDIUM — use strategy `weighted_merge_flag_divergence`
   - `avg < 0.40`: LOW — use strategy `present_all_flag_for_user`
6. **Semantic cross-check** (corrective — may adjust convergence level): After Jaccard classification, compute file:line overlap — count findings where 2+ reviewers reference the same file and line (within 5-line proximity). Compare:
   - Keyword HIGH but file:line overlap LOW → demote convergence one level (HIGH→MEDIUM). Reviewers share vocabulary but found different issues.
   - Keyword LOW but file:line overlap HIGH → promote convergence one level (LOW→MEDIUM). Reviewers describe the same issues using different terms.
   - Log any adjustment: "Convergence adjusted {old}→{new}: keyword={keyword_level}, file:line={overlap_level}"
7. Pass strategy to Section 4.3 to adapt consolidation behavior:
   - `standard_merge_deduplicate`: normal merge (current behavior)
   - `weighted_merge_flag_divergence`: on severity conflicts, keep higher severity + note "[Divergent]"
   - `present_all_flag_for_user`: skip dedup, present all, add header "Low reviewer agreement — manual review recommended"

### Limitations

> **NOTE:** Jaccard similarity measures vocabulary overlap, not semantic agreement. Reviewers sharing domain vocabulary may score HIGH even with different conclusions. Conversely, cross-tier reviewers (Tier A native vs Tier C CLI) may use different vocabulary for the same findings, depressing scores. When `features.stances` is also `true`, stance-biased reviewers (advocate vs challenger) may naturally diverge in vocabulary framing, which can systematically lower convergence scores. Interpret convergence levels as a heuristic signal, not a definitive measure of agreement.

### Output

Store `convergence_stats` in summary flags (Section 4.5).

## 4.3 Finding Consolidation

After all reviewers complete, consolidate findings:

### Severity Classification

Use the canonical severity levels defined in SKILL.md: Critical, High, Medium, Low.

### Confidence Scoring

Before deduplication, assign a confidence score to each finding using these inline values:

| Factor | Points | Condition |
|--------|--------|-----------|
| Base | 40 | Every finding starts here |
| Consensus | +25 | 2+ tiers flagged the same issue (same file:line or semantically equivalent) |
| File:line reference | +15 | Finding includes exact file path and line number |
| Code snippet | +10 | Finding includes a code excerpt demonstrating the issue |
| Known pattern | +10 | Finding matches a known anti-pattern from escalation triggers or skill references |

**Progressive threshold filtering** — after scoring, apply minimum confidence thresholds (inline defaults):
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

After deduplication, review each Medium-severity finding against these inline escalation triggers. For each Medium finding:

1. Check if the finding matches ANY of these triggers:
   - **User-visible data corruption**: data written to storage/network may be incorrect under specific conditions
   - **Implicit ordering dependency**: code assumes execution order that is not guaranteed
   - **UI state contradiction**: two UI components can reach conflicting visible states simultaneously
   - **Singleton state leak**: shared mutable state can bleed across user sessions or test runs
   - **Race condition with user-visible effect**: concurrent code paths can produce inconsistent UI or data outcomes
2. If a match is found, promote the finding from Medium to High
3. Log each promotion: "Reclassified [M{N}] → [H{N+offset}]: matches escalation trigger '{trigger}'"

This pass runs AFTER deduplication so that consensus-boosted findings are also checked.

> **Note:** Findings promoted by escalation triggers intentionally bypass the confidence threshold for their new severity level. A Medium finding at score 75 promoted to High (threshold 65) is retained without re-filtering. This is by design — escalation triggers represent domain knowledge that overrides statistical confidence.

### Stance Divergence Analysis (Optional)

> Conditional: Only when `features.stances` is `true` (from Stage 1 summary) AND all 3 base reviewers completed.

For each finding assessed by multiple base reviewers (from deduplication), compare severity across stances:

1. Compute `severity_spread = max_ordinal - min_ordinal` (low=0, medium=1, high=2, critical=3)
2. Classify using inline thresholds (`low_threshold=0`, `moderate_threshold=1`, `high_threshold=2`):
   - spread <= 0: accept majority severity
   - spread <= 1: accept majority, append note
   - spread >= 2: flag "[DIVERGENCE]" with per-stance breakdown, recommend manual review

Track `high_divergence_count` and `stance_adjustments` for summary.

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

## 4.3b CoVe Post-Synthesis (Optional)

> Conditional: Only when ALL of:
>   1. `features.cove` is `true` (from Stage 1 summary)
>   2. Multi-tier review was used (>= 2 of Tiers A, B, C ran)
>   3. Critical + High findings after confidence scoring >= 2 (inline default: `min_findings_trigger=2`)
> If any condition fails, skip to Section 4.4.

Run Chain-of-Verification to validate Critical/High findings against actual code.

### Procedure

1. Collect all Critical + High findings from Section 4.3 output
2. Dispatch throwaway `Task(subagent_type="general-purpose")` with CoVe prompt:

> You are a code verification agent. Verify review findings by reading source code.
>
> ## Findings to Verify
> {findings_list}
>
> ## Instructions
> For EACH finding:
> 1. Generate 3-5 verification questions targeting the claim (inline defaults: `min=3`, `max=5`)
> 2. Answer each by reading the actual code (use Read/Glob/Grep — do NOT guess)
> 3. Determine VERIFIED (code has the issue) or REJECTED (false positive)
> 4. For REJECTED: explain why (e.g., "validated at helper.ts:45 before use")
>
> ## Output
> Per finding: finding_id, verified (true/false), questions_asked, reason
> Summary: findings_verified, findings_rejected, total_questions

Variables:
- `{findings_list}` — Critical+High findings with IDs, descriptions, file:line, severity
- `{min}` = 3, `{max}` = 5 (inline defaults)

3. Parse output: remove findings where `verified: false`
4. Log each removal: "CoVe removed [{id}]: {reason}"
5. Update consolidated list

### Output

Store `cove_stats` in summary flags (Section 4.5).

## 4.4 User Decision

Before writing the summary, apply the auto-decision matrix. The autonomy policy from Stage 1 summary EXTENDS the base auto-decision matrix — it does not replace it. The base matrix handles the "no findings" and "low-only" cases that are always auto-accepted. The autonomy policy handles the cases that would otherwise escalate to the user.

### Auto-Decision Logic (Base Matrix)

Inline auto-decision defaults (`auto_accept_low_only=true`, `medium_max_count=3`):

1. **No findings**: Set `status: completed`, `review_outcome: "accepted"` — no user interaction needed
2. **All findings Low only**: Auto-accept. Set `status: completed`, `review_outcome: "accepted"`, log: "Auto-accepted: {N} Low findings"
3. **Highest is Medium AND medium count <= 3**: Auto-accept with note. Set `status: completed`, `review_outcome: "accepted"`, log: "Auto-accepted: {N} Medium + {M} Low findings (within threshold)"
4. **Any Critical or High, OR medium count > 3**: Check autonomy policy (below)

### Autonomy Policy Check (extends base matrix)

Read `autonomy` from the Stage 1 summary. Use the policy level from `autonomy.level` to look up behavior.

For each severity level present in findings (Critical, High, Medium), look up `policy.findings.{severity}`:
- **`"fix"`**: Add to the auto-fix list
- **`"defer"`**: Add to the defer list (will be written to `review-findings.md`)
- **`"accept"`**: Accept silently

Then apply:
- If auto-fix list is non-empty: Auto-fix — launch `{vertical_agent_type}` fix agent (read from Stage 2 summary `flags.vertical_agent_type`, defaulting to `developer`) for findings in the fix list. Log: `"[AUTO-{policy}] Auto-fixing {N} findings ({severity_breakdown})"`. After fix, run test count cross-validation (same as manual "Fix now"). Write deferred findings to `review-findings.md`. Set `review_outcome: "fixed"`.
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

**Native fix path:**
1. Read `flags.vertical_agent_type` from the Stage 2 summary (defaulting to `developer` if not present)
2. Launch a `{vertical_agent_type}` agent with the fix prompt template from `agent-prompts.md` (Section: Review Fix Prompt):
   ```
   Task(subagent_type="product-implementation:{vertical_agent_type}")
   ```
3. Agent addresses Critical and High findings

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

## 4.4a Protocol Compliance Checklist

Before writing the Stage 4 summary, complete the **Stage 4** checklist in `$CLAUDE_PLUGIN_ROOT/skills/implement/references/protocol-compliance-checklist.md` (Universal Checks + Stage 4 section). Record results in `protocol_evidence`.

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
  convergence_stats: null    # Section 4.3a: {avg_similarity, level, strategy_used, pairwise_scores}
  stance_stats: null         # Section 4.2/4.3: {high_divergence_count, stance_adjustments, stances_used}
  cove_stats: null           # Section 4.3b: {findings_before, findings_after, questions_generated, findings_removed}
  cli_circuit_state: null    # Propagated from Stage 2/3, updated by Tier C dispatches
  context_contributions: null
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
