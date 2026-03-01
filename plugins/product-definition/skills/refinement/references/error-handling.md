# Error Handling

> Shared reference for error recovery and graceful degradation in the Requirements Refinement workflow.

## Tool Errors

1. Log error to state file
2. Offer recovery options
3. If critical: abort with clear message

## PAL Service Unavailable

1. Log: "PAL service unavailable"
2. Offer: Retry, Skip, Manual review
3. **Graceful Degradation:** Fall back to Standard/Rapid modes

---

## PAL Model Failure Notification Format

When ANY PAL model fails, display this notification:

```
+-----------------------------------------------------------+
| WARNING: PAL MODEL FAILURE                                 |
+-----------------------------------------------------------+
| Model:     {MODEL_NAME}                                    |
| Stage:     {STAGE_NUMBER} - {STAGE_NAME}                   |
| Operation: {thinkdeep|consensus}                           |
| Error:     {ERROR_MESSAGE}                                 |
|                                                            |
| Remaining models: {COUNT} of {TOTAL}                       |
| Minimum required: 2                                        |
+-----------------------------------------------------------+
```

**Options:**
1. **Retry** - Attempt {MODEL_NAME} again
2. **Continue** - Proceed with {REMAINING_COUNT} models (if >= 2)
3. **Abort** - Stop workflow and preserve state

**If remaining models < 2:**
ABORT workflow with message:
```
Cannot continue: PAL Consensus requires minimum 2 models.
Only {COUNT} model(s) available. Please check PAL configuration.
```

---

## Model Failure Logging

When a model fails, log to state file:

```yaml
model_failures:
  - model: "{MODEL_NAME}"
    stage: {STAGE_NUMBER}
    operation: "{thinkdeep|consensus}"
    error: "{ERROR_MESSAGE}"
    timestamp: "{ISO_TIMESTAMP}"
    action_taken: "{retry|continue|abort}"
```

---

## Recovery Procedures

### ThinkDeep Failure Recovery (Stage 3)

1. Log the failure
2. Display notification
3. Ask user: Retry, Continue (if >= 2 models), or Abort
4. If "Continue": Mark model as skipped, proceed with remaining
5. Update state with `thinkdeep_failures` array

### ThinkDeep Auto-Downgrade

After all ThinkDeep chains complete (or fail), calculate `thinkdeep_completion_pct`:

```
thinkdeep_completion_pct = (successful_calls / expected_calls) * 100

IF thinkdeep_completion_pct < config -> scoring.thinkdeep_completion.auto_downgrade_pct (default: 40%):
    Notify user: "ThinkDeep analysis severely degraded ({completion_pct}% completed).
                  Automatically downgrading to Standard mode for this round."
    Present override option via AskUserQuestion:
      - "Accept downgrade to Standard (Recommended)"
      - "Continue with degraded ThinkDeep results"
      - "Abort and investigate PAL issues"
    IF user accepts downgrade:
        SET ANALYSIS_MODE = "standard" for this round
        Skip remaining ThinkDeep calls
        Proceed to Part B with no ThinkDeep insights
    Log: auto_downgrade event in state file
```

This is also checked in `quality-gates.md` -> After Stage 3 as a blocking gate.

### Consensus Failure Recovery (Stages 4, 5)

1. Log the failure
2. Display notification
3. If < 2 models available: ABORT (consensus requires minimum 2)
4. If >= 2 models: Ask user to Continue or Abort
5. Update state with `consensus_failures` array

---

## Graceful Degradation (Plugin Mode)

When MCP tools are unavailable at startup (detected in Stage 1):

### PAL Unavailable
- Notify user: "PAL tools unavailable. Complete and Advanced modes disabled."
- Limit mode selection to: Standard, Rapid
- Skip ThinkDeep in Stage 3 entirely
- Skip PAL Consensus in Stages 4 & 5
- Use internal validation instead

### Sequential Thinking Unavailable
- Notify user: "Sequential Thinking unavailable. Using internal reasoning."
- Replace ST calls with internal multi-step reasoning
- Mark outputs as "Generated without Sequential Thinking"

### Research MCP Unavailable
- No notification needed -- manual research is the default flow
- Auto-research option is simply not presented in Stage 2 decision
- All analysis modes remain available (research MCP is orthogonal to PAL/ST)

---

## Research MCP Failure Recovery (Stage 2)

Research MCP failures are **non-blocking** -- research is optional, and auto-research is a convenience enhancement.

### Tavily Search Failure

```
+-----------------------------------------------------------+
| NOTE: RESEARCH MCP ISSUE                                   |
+-----------------------------------------------------------+
| Tool:      tavily_search                                   |
| Error:     {ERROR_MESSAGE}                                 |
| Queries:   {COMPLETED}/{TOTAL} completed before failure    |
+-----------------------------------------------------------+
```

**Action:**
1. Log failure to state: `model_failures.append({tool: "tavily_search", stage: 2, error: "...", timestamp: "..."})`
2. If some queries completed: Use partial results, note incompleteness in synthesis
3. If no queries completed: Fall back to manual research flow (offer agenda generation)
4. **Never block the workflow** -- research is optional

### Ref Documentation Failure
- **Action:** Log, skip tech documentation section, proceed with Tavily results only
- **Non-critical:** Ref lookup is supplementary to market research
- No user notification needed unless user explicitly chose tech doc lookup

### Rate Limit / Credit Exhaustion
- **Action:** Use results obtained so far
- **Notify user:** "Auto-research partially completed ({N}/{M} queries). Proceeding with available results."
- **Budget tracking:** Log `queries_used` vs `max_searches_per_round` in stage summary

---

## Panel Builder Failure Recovery (Stage 1)

If the Panel Builder subagent fails (crash, timeout, no output):

1. Notify user: "Panel Builder failed. Falling back to default preset."
2. Read default preset from `config/requirements-config.yaml` -> `panel.default_preset` (default: `product-focused`)
3. Build panel config from preset members + `panel.available_perspectives` registry
4. Write directly to `requirements/.panel-config.local.md`
5. Log: `model_failures.append({tool: "panel-builder", stage: 1, error: "...", action_taken: "fallback_to_default_preset"})`
6. Continue to Step 1.9 (State Initialization)

**Key:** Panel Builder failure is **non-blocking** -- the default preset always produces a valid panel.

---

## Coordinator Timeout

Coordinators self-enforce a soft timeout from config `token_budgets.stage_dispatch_profiles.stage_N.timeout_minutes`:

```
IF elapsed_time > timeout_minutes:
    Write partial summary with:
      status: completed
      flags:
        timeout: true
        partial: true
        completed_steps: [list of steps completed before timeout]
    Proceed with whatever artifacts were produced
```

The orchestrator reads `flags.timeout: true` and notifies the user: "Stage {N} timed out after {M} minutes. Proceeding with partial results."

---

## Known Limitations

- **Lock race condition**: The lock file mechanism assumes single-session usage. If two CLI sessions invoke the workflow simultaneously, both may acquire the lock. This is acceptable because Claude Code is inherently single-session per project directory.

---

## Critical Rules

1. **Never substitute models** - If gpt-5.2 fails, do not use a different model in its place. _Note: This is an intentional deviation from PAL mastery's "graceful degradation" guidance. In requirements workflows, PRD decisions must be traceable to specific models for audit purposes. Swapping a different model mid-workflow would break traceability of which model influenced which product decision._
2. **Always notify user** - Every failure must be shown to the user
3. **Minimum 2 for consensus** - PAL Consensus cannot proceed with < 2 models
4. **Log everything** - All failures and recovery actions must be logged to state
5. **Graceful degradation** - If MCP unavailable, fall back to internal capabilities
