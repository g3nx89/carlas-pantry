---
stage: stage-2-spec-draft
artifacts_written:
  - specs/{FEATURE_DIR}/analysis/review-board-synthesis.md (conditional)
---

# Adversarial Review Board Protocol

> Dispatched in Stage 2 after CLI Challenge completes (Step 2.4) and BEFORE gates (Step 2.5).
> Uses TeamCreate to create a 3-critic review board that cross-examines the spec using
> CLI challenge findings as input. Produces a confidence-scored gap list that informs
> downstream gate evaluations.

## Prerequisites

- `REVIEW_BOARD_ENABLED == true` (from dispatch context, resolved in Stage 1)
- `specs/{FEATURE_DIR}/spec.md` exists (from Step 2.1)
- CLI Challenge findings exist at `specs/{FEATURE_DIR}/analysis/mpa-challenge-parallel.md` (optional — board works without them)

---

## Step RB.1: Create Team

```
TeamCreate(
  team_name: "specify-{FEATURE_ID}-review-board",
  description: "Adversarial review of spec for {FEATURE_NAME}"
)

IF TeamCreate fails:
    LOG: "Review board unavailable — falling back to parallel Task dispatch"
    GOTO Fallback Protocol (below)
```

---

## Step RB.2: Spawn Critics

Spawn 3 agents via `Agent` tool with `team_name`:

| Name | CRITIC_ROLE | EVALUATION_LENS | Rubric Focus |
|------|-------------|-----------------|--------------|
| `product-critic` | Product Strategist | Business value, problem validity, market fit | Gates 1+2 rubrics (problem quality + true need) |
| `ux-critic` | UX Analyst | Journey completeness, missing states, edge cases | Checklist + edge case audit rubrics |
| `technical-critic` | Technical Reviewer | AC testability, NFR measurability, constraints | QA strategist rubrics |

Each agent is dispatched with:
```
Agent(
  team_name: "specify-{FEATURE_ID}-review-board",
  name: "{critic-name}",
  subagent_type: "general-purpose",
  prompt: """
    Read agent instructions: @$CLAUDE_PLUGIN_ROOT/agents/review-board-critic.md

    CRITIC_ROLE: {role}
    EVALUATION_LENS: {lens}
    RUBRIC_CONTENT: {rubric — use role-specific default from agent file}
    FEATURE_DIR: specs/{FEATURE_DIR}
    SPEC_FILE: specs/{FEATURE_DIR}/spec.md
    CLI_FINDINGS_FILE: specs/{FEATURE_DIR}/analysis/mpa-challenge-parallel.md
  """
)
```

---

## Step RB.3: Monitor & Wait

The team lead (coordinator) monitors team progress:

```
WAIT for all 3 critics to complete Phase 4 (Final Findings)
TIMEOUT: 180 seconds (3 minutes)

IF timeout:
    Collect whatever findings have been sent so far
    LOG: "Review board timed out — using partial findings"
```

---

## Step RB.4: Synthesis

Read all critic messages. Synthesize into unified gap list with confidence scoring.

### Confidence Aggregation Rules

| Condition | Confidence |
|-----------|-----------|
| 3/3 critics agree on a finding | **HIGH** |
| 2/3 critics agree | **MEDIUM** (elevated to HIGH if CLI also flagged) |
| 1/3 only | **LOW** (include but flag as single-perspective) |
| CLI + any critic agree | Bump confidence one tier |

### Severity Rules

- Severity = highest severity assigned by any agreeing critic
- If CLI challenge also flagged the issue: bump severity one tier (MEDIUM→HIGH, HIGH→CRITICAL)
- CRITICAL findings from a single critic remain CRITICAL (severity never downgraded)

### Deduplication

- Merge findings about the same spec section/requirement
- Keep the richest description (most evidence)
- List all contributing critics in `cross_validated_by`

---

## Step RB.5: Write Synthesis Report

Write to `specs/{FEATURE_DIR}/analysis/review-board-synthesis.md`:

```markdown
# Review Board Synthesis

## Summary
| Metric | Value |
|--------|-------|
| Critics | 3 (product, ux, technical) |
| Total findings | {N} |
| HIGH confidence | {N} |
| MEDIUM confidence | {N} |
| LOW confidence | {N} |
| Cross-validated (2+ agree) | {N} |
| CLI-corroborated | {N} |

## Findings

### CRITICAL
{findings with CRITICAL severity, sorted by confidence desc}

### HIGH
{findings with HIGH severity, sorted by confidence desc}

### MEDIUM
{findings with MEDIUM severity, sorted by confidence desc}

## Cross-Examination Summary
{notable agreements, disagreements, and triggered findings}
```

---

## Step RB.6: Cleanup

```
SendMessage(to: "product-critic", message: {type: "shutdown_request", reason: "Review complete"})
SendMessage(to: "ux-critic", message: {type: "shutdown_request", reason: "Review complete"})
SendMessage(to: "technical-critic", message: {type: "shutdown_request", reason: "Review complete"})

WAIT for shutdown_response from each (timeout: 30s)

TeamDelete(team_name: "specify-{FEATURE_ID}-review-board")
```

---

## Fallback Protocol

When TeamCreate fails (feature not enabled, experimental flag not set):

```
DISPATCH 3 parallel Task() calls (no cross-examination):

Task A: gate-judge with Product Strategist rubric → product-findings.md
Task B: gate-judge with UX Analyst rubric → ux-findings.md
Task C: gate-judge with Technical Reviewer rubric → technical-findings.md

WAIT for all 3 to complete

SYNTHESIZE findings into review-board-synthesis.md:
    - No cross-examination data (cross_validated_by = [])
    - Confidence based on evidence strength only (no multi-critic boost)
    - Same output format as team-based synthesis
```

This ensures the review board produces output regardless of TeamCreate availability — the quality of cross-examination is reduced, but coverage is preserved.

---

## Integration with Stage 2

- Review board runs AFTER Step 2.4 (CLI Challenge) and BEFORE Step 2.5 (Quality Gates)
- Gate judges still run after the review board (they are calibrated rubric evaluations; review board is adversarial debate)
- Review board findings are passed as additional context to gate judges:
  ```
  {IF review-board-synthesis.md exists: Review Board Findings: @specs/{FEATURE_DIR}/analysis/review-board-synthesis.md}
  ```
- Gate evaluation scores are INDEPENDENT of review board findings — review board informs but doesn't override gate scoring

---

## Summary Contract Additions

When review board runs, add to Stage 2 summary flags:

```yaml
flags:
  # ... existing flags ...
  review_board_ran: true
  review_board_findings: {N}
  review_board_high_confidence: {N}
  review_board_cross_validated: {N}
  review_board_cli_corroborated: {N}
```
