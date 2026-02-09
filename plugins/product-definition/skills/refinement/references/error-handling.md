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

---

## Critical Rules

1. **NEVER substitute models** - If gpt-5.2 fails, do NOT use a different model in its place. _Note: This is an intentional deviation from PAL mastery's "graceful degradation" guidance. In requirements workflows, PRD decisions must be traceable to specific models for audit purposes. Swapping a different model mid-workflow would break traceability of which model influenced which product decision._
2. **ALWAYS notify user** - Every failure must be shown to the user
3. **Minimum 2 for consensus** - PAL Consensus cannot proceed with < 2 models
4. **Log everything** - All failures and recovery actions must be logged to state
5. **Graceful degradation** - If MCP unavailable, fall back to internal capabilities
