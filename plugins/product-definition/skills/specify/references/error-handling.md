# Error Handling

> Shared reference for error recovery and graceful degradation in the Feature Specify workflow.

## Tool Errors

1. Log error to state file
2. Offer recovery options via summary `status: needs-user-input`
3. If critical: set `status: failed` with clear message

## CLI Dispatch Unavailable

1. Log: "CLI dispatch unavailable (script not found or no CLI binaries in PATH)"
2. Set `CLI_AVAILABLE = false`
3. **Graceful Degradation:** Skip Challenge, EdgeCases, Triangulation, and Evaluation steps — proceed with internal reasoning
4. Notify user: "CLI dispatch unavailable. Multi-model analysis steps will be skipped."

---

## CLI Failure Notification Format

When ANY CLI dispatch fails, the coordinator MUST include this in the summary context:

```
+-----------------------------------------------------------+
| WARNING: CLI DISPATCH FAILURE                              |
+-----------------------------------------------------------+
| CLI:       {CLI_NAME}                                      |
| Role:      {ROLE_NAME}                                     |
| Stage:     {STAGE_NUMBER} - {STAGE_NAME}                   |
| Operation: {challenge|edge_cases|triangulation|evaluation} |
| Exit Code: {EXIT_CODE} — {description}                     |
| Error:     {ERROR_MESSAGE}                                 |
|                                                            |
| CLIs responded: {COUNT} of {TOTAL}                         |
| Minimum required: 2 (for evaluation)                       |
+-----------------------------------------------------------+
```

**Exit code descriptions:**
- `1` = CLI failure (retried, still failing)
- `2` = Timeout
- `3` = CLI not found in PATH
- `4` = Parse failure (output captured but unstructured)

**If substantive responses < 2 for evaluation (Stage 5):**
Signal `needs-user-input` — do NOT self-assess.

---

## CLI Failure Logging

When a CLI fails, log to state file:

```yaml
model_failures:
  - cli: "{CLI_NAME}"
    role: "{ROLE_NAME}"
    stage: {STAGE_NUMBER}
    operation: "{challenge|edge_cases|triangulation|evaluation}"
    exit_code: {EXIT_CODE}
    error: "{ERROR_MESSAGE}"
    timestamp: "{ISO_TIMESTAMP}"
    action_taken: "{retry|continue|skipped}"
```

---

## Recovery Procedures

### CLI Challenge / EdgeCases / Triangulation Failure (Stages 2, 4)

1. Log the failure
2. Include notification in summary context
3. If >= 1 CLI succeeded: continue with partial results (lower coverage but valid)
4. If 0 CLIs succeeded: skip this integration point, proceed with internal reasoning
5. Update state with `model_failures` array

### CLI Evaluation Failure (Stage 5)

1. Log the failure
2. Include notification in summary context
3. If < 2 substantive responses: signal `needs-user-input` (NEVER self-assess)
4. If >= 2 substantive responses: score using available responses, note partial results
5. Update state with `model_failures` array

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

When tools are unavailable at startup (detected in Stage 1):

### CLI Dispatch Unavailable
- Notify user: "CLI dispatch unavailable. Challenge, EdgeCase, Triangulation, and Evaluation steps will be skipped."
- `CLI_AVAILABLE = false` — set in state file
- Skip CLI Challenge in Stage 2
- Skip CLI EdgeCases and Triangulation in Stage 4
- Skip CLI Evaluation in Stage 5 — use internal quality gates instead

### Sequential Thinking Unavailable
- Notify user: "Sequential Thinking unavailable. Using internal reasoning."
- Replace ST calls with internal multi-step reasoning

### Figma MCP Unavailable
- No notification needed — Figma is prompted interactively in Stage 1
- If user chose `--figma` but MCP unavailable: notify and proceed without

---

## Critical Rules

1. **NEVER substitute CLIs** — If a CLI fails, continue with remaining, do NOT swap in another
2. **ALWAYS notify user** — Every failure must be surfaced (via summary context for coordinator-delegated stages)
3. **Minimum 2 for evaluation** — CLI Evaluation cannot be scored with < 2 substantive responses
4. **Log everything** — All failures and recovery actions must be logged to state
5. **Graceful degradation** — If CLI unavailable, fall back to internal capabilities
6. **Mandatory outputs** — design-brief.md and design-supplement.md NEVER skipped, even on failure (retry required)
