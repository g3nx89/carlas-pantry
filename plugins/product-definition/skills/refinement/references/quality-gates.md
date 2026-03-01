# Quality Gates

> Quality checks performed by the orchestrator after stages that produce user-facing artifacts.
> These supplement each coordinator's internal self-verification.

---

## After Stage 3 (Questions Generated)

### Structural Validation (Blocking)

Before quality checks, validate the QUESTIONS file structure:

```
READ requirements/working/QUESTIONS-{NNN}.md

STRUCTURAL CHECKS (blocking -- fail = do not proceed):
1. File exists and is non-empty
2. YAML frontmatter present with round_number and metadata
3. At least 1 question block matching pattern: ## Q-{ID}
4. Each question block has >= 3 checkbox options (- [ ] pattern)
5. No malformed checkbox patterns (e.g., missing brackets)

IF structural validation fails:
    BLOCK: Do not proceed to Stage 4
    Notify user: "QUESTIONS file has structural issues: {list}"
    Ask: "Regenerate questions?" or "Fix manually and re-run?"
```

### Quality Checks (Non-blocking)

```
QUALITY CHECKS:
1. Section coverage: every required PRD section (from config -> prd.sections where required=true)
   has at least 1 question targeting it
2. Option distinctness: spot-check 3 random questions -- options should represent
   genuinely different approaches, not minor variations of the same idea
3. Priority balance: at least 1 CRITICAL question exists; not all questions are MEDIUM
4. ThinkDeep completion (if mode in {complete, advanced}):
   READ flags.thinkdeep_completion_pct from Stage 3 summary
   READ flags.thinkdeep_calls and flags.thinkdeep_expected from Stage 3 summary
   READ minimum_pct from config -> scoring.thinkdeep_completion.minimum_pct
   IF thinkdeep_completion_pct < minimum_pct:
     WARN: "ThinkDeep analysis significantly degraded: {thinkdeep_calls}/{thinkdeep_expected}
            calls succeeded ({thinkdeep_completion_pct}%). Question quality may be reduced
            compared to full {ANALYSIS_MODE} mode. Consider re-running with Standard mode
            if PAL issues persist."
   IF thinkdeep_completion_pct < config -> scoring.thinkdeep_completion.auto_downgrade_pct
      AND auto-downgrade was not already handled by error-handling.md:
     BLOCK: Present decision to user via AskUserQuestion:
       - "Continue with degraded ThinkDeep results"
       - "Re-run Stage 3 in Standard mode (no ThinkDeep)"
       - "Abort and investigate PAL issues"

IF non-blocking issues found:
    LOG quality_warnings in state file
    ADD flags.quality_warnings to Stage 3 summary (append, do not overwrite)
    NOTIFY user: "Quality note: {issue}. Questions are still usable."
    (Do NOT block -- proceed to Stage 4)
```

---

## After Stage 5 (PRD Generated)

### Structural Validation (Blocking)

```
IF flags.validation_decision in ["READY", "CONDITIONAL"]:
    READ requirements/PRD.md

    STRUCTURAL CHECKS (blocking):
    1. PRD section headings: verify all required sections from config -> prd.sections
       are present as markdown headings (## or ###)
    2. Each required section has non-empty content (not just a heading)

    IF structural validation fails:
        BLOCK: Do not proceed to Stage 6
        Notify user: "PRD missing required sections: {list}"
        Set flags.next_action: "loop_questions"
```

### Quality Checks (Non-blocking)

```
IF flags.validation_decision in ["READY", "CONDITIONAL"]:
    QUALITY CHECKS:
    1. Section completeness: all required sections are present and non-empty
       EXCEPTION: "Executive Summary" is a synthesis section generated last --
       exclude it from this check (its absence is not a quality issue)
    2. Technical filter: quick grep for top 5 forbidden keywords
       (API, backend, database, architecture, implementation)
    3. Decision traceability: requirements/decision-log.md exists and is non-empty

    IF issues found:
        LOG quality_warnings in state file
        NOTIFY user before proceeding to Stage 6:
            "Quality note: {issues}. Review PRD.md before finalizing."
```

---

## Rounds-Digest Template

When `current_round > config -> token_budgets.compaction.rounds_before_compaction`, the orchestrator compacts prior round summaries into a digest.

```yaml
---
digest_version: 1
rounds_covered: [1, 2, 3]
generated_at: "{ISO_TIMESTAMP}"
total_questions_asked: {N}
total_questions_answered: {N}
modes_used: ["complete", "standard"]
---
```

```markdown
## Per-Round Summary

| Round | Mode | Questions | Completion | Gaps Found | ThinkDeep % | Outcome |
|-------|------|-----------|------------|------------|-------------|---------|
| 1 | complete | 14 | 100% | 3 | 100% | loop_questions |
| 2 | standard | 8 | 100% | 1 | N/A | proceed |
| 3 | standard | 5 | 100% | 0 | N/A | RED (score 11/20) |

## Cumulative User Decisions

| Decision Key | Value | Round |
|-------------|-------|-------|
| analysis_mode_round_1 | complete | 1 |
| analysis_mode_round_2 | standard | 2 |
| gap_action_round_1 | loop_questions | 1 |

## Persistent Gap Tracker

Track gap IDs that persist across rounds (used by REFLECTION_CONTEXT):

| Gap ID | Section | First Seen | Status | Resolved In |
|--------|---------|------------|--------|-------------|
| GAP-001 | Revenue Model | Round 1 | resolved | Round 2 |
| GAP-002 | Target Users | Round 1 | open | -- |
| GAP-003 | Workflows | Round 2 | open | -- |

## Key Insights (1 line per round)

- **Round 1**: Initial 14 questions; ThinkDeep flagged revenue model uncertainty as CRITICAL
- **Round 2**: Follow-up 8 questions resolved revenue model; new gaps in workflows
- **Round 3**: Validation RED (11/20) -- weak on workflows and feature inventory
```

**Digest rules:**
- Total must not exceed `config -> token_budgets.compaction.digest_max_lines` (default: 100 lines)
- Persistent Gap Tracker must include gap IDs that survive compaction for cross-round reflection
- Per-Round Summary includes ThinkDeep completion % to track degradation history
