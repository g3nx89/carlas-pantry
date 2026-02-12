# Error Handling

> Shared reference for error recovery and graceful degradation in the Feature Specify workflow.

## Tool Errors

1. Log error to state file
2. Offer recovery options via summary `status: needs-user-input`
3. If critical: set `status: failed` with clear message

## PAL Service Unavailable

1. Log: "PAL service unavailable"
2. Signal `needs-user-input` with options: Retry, Skip, Abort
3. **Graceful Degradation:** Skip ThinkDeep and Consensus steps — proceed with internal reasoning

---

## PAL Model Failure Notification Format

When ANY PAL model fails, the coordinator MUST include this in the summary context:

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
| Minimum required: 2 (for consensus)                        |
+-----------------------------------------------------------+
```

**If remaining models < 2 for consensus:**
Set `status: failed` with message:
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

### ThinkDeep Failure Recovery (Stages 2, 4)

1. Log the failure
2. Include notification in summary context
3. If >= 1 model succeeded: continue with partial results
4. If 0 models succeeded: skip ThinkDeep, proceed with internal reasoning
5. Update state with `thinkdeep_failures` array

### Consensus Failure Recovery (Stage 5)

1. Log the failure
2. Include notification in summary context
3. If < 2 models available: set `status: failed` (consensus requires minimum 2)
4. If >= 2 models: continue with available models, note partial results
5. Update state with `consensus_failures` array

---

## Figma Service Failure

1. Log: "Figma MCP unavailable or returned error"
2. Set `FIGMA_MCP_AVAILABLE = false`
3. Continue without Figma context — this is non-blocking
4. Notify user: "Figma integration skipped due to service error."

## Gate Evaluation Failure

1. Log: "Gate evaluation failed for gate {GATE_ID}"
2. Default to YELLOW (conservative) — do NOT assume GREEN on failure
3. Signal `needs-user-input` with gate failure details
4. User decides: retry, proceed, or abort

## Design Brief/Supplement Generation Failure

1. Log: "Agent {AGENT_NAME} failed to produce output"
2. **CRITICAL:** design-brief.md and design-supplement.md are MANDATORY
3. If agent fails: retry once
4. If retry fails: set `status: failed` — do NOT skip mandatory outputs

## QA Strategist Failure

1. Log: "QA strategist failed to produce test-plan.md"
2. Test strategy is optional (feature flag controlled)
3. If feature flag enabled and agent fails: retry once
4. If retry fails: signal `needs-user-input` (skip test strategy / retry / abort)

---

## Graceful Degradation (Plugin Mode)

When MCP tools are unavailable at startup (detected in Stage 1):

### PAL Unavailable
- Notify user: "PAL tools unavailable. ThinkDeep and Consensus steps will be skipped."
- Skip ThinkDeep in Stages 2, 4
- Skip PAL Consensus in Stage 5
- Use internal validation instead

### Sequential Thinking Unavailable
- Notify user: "Sequential Thinking unavailable. Using internal reasoning."
- Replace ST calls with internal multi-step reasoning

### Figma MCP Unavailable
- No notification needed — Figma is prompted interactively in Stage 1
- If user chose `--figma` but MCP unavailable: notify and proceed without

---

## Critical Rules

1. **NEVER substitute models** — If a model fails, continue with remaining, do NOT swap in another
2. **ALWAYS notify user** — Every failure must be surfaced (via summary context for coordinator-delegated stages)
3. **Minimum 2 for consensus** — PAL Consensus cannot proceed with < 2 models
4. **Log everything** — All failures and recovery actions must be logged to state
5. **Graceful degradation** — If MCP unavailable, fall back to internal capabilities
6. **Mandatory outputs** — design-brief.md and design-supplement.md NEVER skipped, even on failure (retry required)
