---
phase: phase-6-validation
artifacts_written:
  - "{FEATURE_DIR}/analysis/review-board-synthesis.md (conditional)"
---

# Adversarial Review Board Protocol

> Dispatched in Phase 6 after CLI Consensus Scoring (Step 6.4), perspective-critic team debate,
> and Score Divergence Check (Step 6.5) — BEFORE the final verdict (GREEN/YELLOW/RED).
> Uses TeamCreate to spawn a 3-critic review board that cross-examines the plan using
> CLI consensus findings as input. Produces a confidence-scored finding list that informs
> verdict adjustment.

## Prerequisites

- `state.review_board_enabled == true` (from Step 1.10 team preset)
- `AGENT_TEAMS_AVAILABLE == true`
- Preliminary verdict is **YELLOW or RED** (`total_score < 16`)
- `{FEATURE_DIR}/plan.md` exists (from Phase 4)
- `{FEATURE_DIR}/analysis/cli-consensus-report.md` exists (optional -- board works without it)

**Skip condition:** If the preliminary verdict is GREEN (total_score >= 16), the review board is SKIPPED. A passing plan does not benefit from adversarial review.

---

## Step RB.1: Create Team

```
TeamCreate(
  team_name: "planning-{FEATURE_ID}-review-board",
  description: "Adversarial review of plan for {FEATURE_NAME}"
)

IF TeamCreate fails:
    LOG: "Review board unavailable -- falling back to parallel Task dispatch"
    GOTO Fallback Protocol (below)
```

---

## Step RB.2: Spawn Critics

Spawn 3 agents via `Agent` tool with `team_name`:

| Name | CRITIC_ROLE | EVALUATION_LENS | Focus |
|------|-------------|-----------------|-------|
| `plan-quality-critic` | Plan Quality Critic | Plan coherence, task ordering, dependencies | Does the plan make logical sense? |
| `risk-critic` | Risk Assessor | Risk identification, failure modes, mitigations | Are all risks covered with adequate mitigations? |
| `scope-critic` | Scope Guardian | Over-engineering, YAGNI, unnecessary complexity | Is the plan minimal and focused? |

Each agent is dispatched with:
```
Agent(
  team_name: "planning-{FEATURE_ID}-review-board",
  name: "{critic-name}",
  subagent_type: "general-purpose",
  prompt: """
    Read agent instructions: @$CLAUDE_PLUGIN_ROOT/agents/review-board-critic.md

    CRITIC_ROLE: {role}
    EVALUATION_LENS: {lens}
    ROLE_PREFIX: {prefix}  # PQ for plan-quality, RA for risk, SG for scope
    PEER_NAMES: {comma-separated names of other 2 critics on this board}
    FEATURE_DIR: {FEATURE_DIR}
    PLAN_FILE: {FEATURE_DIR}/plan.md
    SPEC_FILE: {FEATURE_DIR}/spec.md
    DESIGN_FILE: {FEATURE_DIR}/design.md
    CLI_CONSENSUS_FILE: {FEATURE_DIR}/analysis/cli-consensus-report.md
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
    LOG: "Review board timed out -- using partial findings"
```

---

## Step RB.4: Synthesis

Read all critic messages. Synthesize into unified finding list with confidence scoring.

### Confidence Aggregation Rules

| Condition | Confidence |
|-----------|-----------|
| 3/3 critics agree on a finding | **HIGH** |
| 2/3 critics agree | **MEDIUM** (elevated to HIGH if CLI also flagged) |
| 1/3 only | **LOW** (include but flag as single-perspective) |
| CLI + any critic agree | Bump confidence one tier |

### Severity Rules

- Severity = highest severity assigned by any agreeing critic
- If CLI consensus report also flagged the issue: bump severity one tier (MEDIUM->HIGH, HIGH->CRITICAL)
- CRITICAL findings from a single critic remain CRITICAL (severity never downgraded)

### Deduplication

- Merge findings about the same plan section, task, or dependency
- Keep the richest description (most evidence)
- List all contributing critics in `cross_validated_by`

---

## Step RB.5: Write Synthesis Report

Write to `{FEATURE_DIR}/analysis/review-board-synthesis.md`:

```markdown
# Review Board Synthesis

## Summary
| Metric | Value |
|--------|-------|
| Critics | 3 (plan-quality, risk, scope) |
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
SendMessage(to: "plan-quality-critic", message: {type: "shutdown_request", reason: "Review complete"})
SendMessage(to: "risk-critic", message: {type: "shutdown_request", reason: "Review complete"})
SendMessage(to: "scope-critic", message: {type: "shutdown_request", reason: "Review complete"})

WAIT for shutdown_response from each (timeout: 30s)

TeamDelete(team_name: "planning-{FEATURE_ID}-review-board")
```

---

## Step RB.7: Verdict Adjustment

After review board synthesis, adjust the preliminary verdict:

| Board Findings | Verdict Adjustment |
|----------------|-------------------|
| 0 CRITICAL + 0 HIGH | Keep original verdict (YELLOW or RED unchanged) |
| 1+ CRITICAL | Downgrade to **RED** (regardless of original) |
| 1+ HIGH (no CRITICAL) | Keep **YELLOW** |

**Constraint:** The review board can only **downgrade or maintain** a verdict. It CANNOT upgrade (e.g., YELLOW->GREEN). The board is adversarial by design -- its purpose is to find reasons NOT to proceed, not to validate the plan.

---

## Fallback Protocol

When TeamCreate fails (feature not enabled, experimental flag not set):

```
DISPATCH 3 parallel Task() calls (no cross-examination):

Task A: review-board-critic with Plan Quality Critic rubric -> plan-quality-findings.md
Task B: review-board-critic with Risk Assessor rubric -> risk-findings.md
Task C: review-board-critic with Scope Guardian rubric -> scope-findings.md

WAIT for all 3 to complete

SYNTHESIZE findings into review-board-synthesis.md:
    - No cross-examination data (cross_validated_by = [])
    - Confidence based on evidence strength only (no multi-critic boost)
    - Same output format as team-based synthesis
```

This ensures the review board produces output regardless of TeamCreate availability -- the quality of cross-examination is reduced, but coverage is preserved.

---

## Integration with Phase 6

### Execution Sequence

```
Step 6.4: CLI Consensus Scoring (dimensional scores averaged)
    |
    v
Perspective-critic team debate (if enabled)
    |
    v
Step 6.5: Score Divergence Check
    |
    v
Preliminary verdict computed (GREEN / YELLOW / RED)
    |
    v
IF GREEN: SKIP review board, proceed to Step 6.7
IF YELLOW or RED:
    |
    v
*** Review Board Protocol (RB.1 - RB.7) ***
    |
    v
Step 6.7: Final verdict (may be adjusted by RB.7)
```

### Context Passing

Review board findings are passed as additional context to the Phase 6 verdict output:
```
{IF review-board-synthesis.md exists: Review Board Findings: @{FEATURE_DIR}/analysis/review-board-synthesis.md}
```

The review board does NOT replace CLI consensus scoring or perspective-critic debate. It is an additional adversarial layer that runs only when the plan has already been flagged as below-threshold.

---

## Summary Contract Additions

When review board runs, add to Phase 6 summary flags:

```yaml
flags:
  # ... existing flags ...
  review_board_ran: true
  review_board_findings: {N}
  review_board_high_confidence: {N}
  review_board_cross_validated: {N}
```
