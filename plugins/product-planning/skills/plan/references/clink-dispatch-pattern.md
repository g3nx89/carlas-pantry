# Clink Dual-CLI Dispatch Pattern

> **Canonical reference for clink integration steps in all phases.**
> Each phase file specifies parameters; this file defines the execution pattern.

## Prerequisites

Before executing this pattern, the calling phase MUST verify:

```
IF state.clink.available AND state.clink.mode != "disabled"
   AND feature_flags.clink_custom_roles.enabled
   AND {MODE_CHECK}:
  EXECUTE pattern below
ELSE:
  LOG: "Clink unavailable or mode mismatch — skipping {ROLE} step"
  SKIP
```

## Parameters (provided by calling phase)

| Parameter | Description |
|-----------|-------------|
| `ROLE` | Clink role name (deepthinker, planreviewer, teststrategist, securityauditor, taskauditor) |
| `PHASE_STEP` | Step number in the calling phase (e.g., 5.6, 6.0a) |
| `MODE_CHECK` | Analysis mode condition (e.g., `analysis_mode in {complete, advanced}`) |
| `GEMINI_PROMPT` | Prompt text for Gemini CLI |
| `CODEX_PROMPT` | Prompt text for Codex CLI |
| `FILE_PATHS` | Array of absolute file paths to pass to clink |
| `REPORT_FILE` | Output report path relative to `{FEATURE_DIR}/` |
| `PREFERRED_SINGLE_CLI` | Which CLI to prefer in single-CLI fallback (`gemini` or `codex`) |
| `POST_WRITE` | Optional post-write action (e.g., append to another file, merge findings) |

## Step A: Parallel Dual-CLI Dispatch (with Retry)

```
max_retries = config.clink_integration.retry.max_retries  # default: 1
timeout = config.clink_integration.timeout.per_role.{ROLE}  # default: 120s

IF state.clink.mode == "dual":
  # Launch BOTH in parallel
  FOR attempt IN [1..max_retries + 1]:
    gemini_result = clink(
      cli_name: "gemini",
      role: "{ROLE}",
      prompt: "{GEMINI_PROMPT}",
      absolute_file_paths: {FILE_PATHS},
      timeout: timeout
    )

    codex_result = clink(
      cli_name: "codex",
      role: "{ROLE}",
      prompt: "{CODEX_PROMPT}",
      absolute_file_paths: {FILE_PATHS},
      timeout: timeout
    )

    IF both succeeded:
      BREAK
    ELSE IF attempt <= max_retries:
      LOG: "Clink {ROLE} attempt {attempt} failed — retrying"
      # Retry only the failed CLI
      CONTINUE
    ELSE:
      # Circuit breaker check
      INCREMENT state.clink.consecutive_failures
      IF state.clink.consecutive_failures >= config.clink_integration.retry.circuit_breaker_threshold:
        LOG: "Circuit breaker triggered — disabling clink for remainder of session"
        SET state.clink.mode = "disabled"
        SKIP remaining clink steps
      # Continue with partial results if one CLI succeeded
      IF gemini_result OR codex_result:
        LOG: "Proceeding with partial clink results (single CLI)"
      ELSE:
        LOG: "Both CLIs failed — skipping {ROLE} step"
        SKIP

ELSE:
  # Single-CLI fallback
  cli = IF state.clink.capabilities.{PREFERRED_SINGLE_CLI} THEN "{PREFERRED_SINGLE_CLI}"
        ELSE (the other CLI)
  FOR attempt IN [1..max_retries + 1]:
    single_result = clink(
      cli_name: cli,
      role: "{ROLE}",
      prompt: (use GEMINI_PROMPT if gemini, else CODEX_PROMPT),
      absolute_file_paths: {FILE_PATHS},
      timeout: timeout
    )
    IF succeeded: BREAK
    ELSE IF attempt <= max_retries: CONTINUE
    ELSE:
      INCREMENT state.clink.consecutive_failures
      IF consecutive_failures >= circuit_breaker_threshold:
        SET state.clink.mode = "disabled"
      SKIP
```

## Step B: Synthesis

```
IF dual results available:
  CATEGORIZE each finding:
    - Convergent (both CLIs agree) -> HIGH confidence
    - Divergent (CLIs disagree) -> FLAG for decision
    - Unique (one CLI only) -> VERIFY against existing findings

ELSE IF single result only:
  MARK all findings as mode: single_{cli_name}
  SKIP synthesis categorization
```

## Step C: Self-Critique via Task Subagent

Run Chain-of-Verification in a separate Task to avoid coordinator context pollution.

```
validated = Task(
  subagent_type: "general-purpose",
  prompt: """
    Apply Chain-of-Verification (CoVe) to these clink {ROLE} findings:

    {synthesized_findings}

    Process:
    1. Generate 3-5 verification questions targeting the highest-risk findings
    2. Answer each question against the evidence provided
    3. Revise or remove findings where verification fails
    4. Return ONLY validated findings in the original output format

    Quality gate: At least 3 verification questions must pass for submission.
  """,
  description: "CoVe self-critique for clink {ROLE}"
)
```

## Step D: Write Validated Report

```
WRITE validated findings to {FEATURE_DIR}/{REPORT_FILE}

# Reset failure counter on success
SET state.clink.consecutive_failures = 0

# Execute optional post-write action
IF {POST_WRITE} defined:
  EXECUTE {POST_WRITE}
```

## Error Handling Summary

| Scenario | Behavior |
|----------|----------|
| Both CLIs succeed | Normal dual-CLI synthesis |
| One CLI fails, retry succeeds | Normal (delayed) |
| One CLI fails after retries | Proceed with single-CLI results |
| Both CLIs fail after retries | Skip clink step, log warning |
| 2+ consecutive failures across phases | Circuit breaker: disable clink for session |
| Self-critique Task fails | Use unsynthesized findings with `flags.degraded: true` |
| Template deployment missing | Phase 1 detection sets `state.clink.mode = "disabled"` |
