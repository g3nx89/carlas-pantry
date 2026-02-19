# CLI Dual-CLI Dispatch Pattern

> **Canonical reference for CLI integration steps in all phases.**
> Each phase file specifies parameters; this file defines the execution pattern.

## Prerequisites

Before executing this pattern, the calling phase MUST verify:

```
IF state.cli.available AND state.cli.mode != "disabled"
   AND feature_flags.cli_custom_roles.enabled
   AND {MODE_CHECK}:
  EXECUTE pattern below
ELSE:
  LOG: "CLI unavailable or mode mismatch — skipping {ROLE} step"
  SKIP
```

## Parameters (provided by calling phase)

| Parameter | Description |
|-----------|-------------|
| `ROLE` | CLI role name (deepthinker, planreviewer, teststrategist, securityauditor, taskauditor) |
| `PHASE_STEP` | Step number in the calling phase (e.g., 5.6, 6.0a) |
| `MODE_CHECK` | Analysis mode condition (e.g., `analysis_mode in {complete, advanced}`) |
| `GEMINI_PROMPT` | Prompt text for Gemini CLI |
| `CODEX_PROMPT` | Prompt text for Codex CLI |
| `FILE_PATHS` | Array of absolute file paths to include in prompt |
| `REPORT_FILE` | Output report path relative to `{FEATURE_DIR}/` |
| `PREFERRED_SINGLE_CLI` | Which CLI to prefer in single-CLI fallback (`gemini` or `codex`) |
| `POST_WRITE` | Optional post-write action (e.g., append to another file, merge findings) |

## Step A: Parallel Dual-CLI Dispatch (with Retry)

```
SCRIPT = "$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh"
max_retries = config.cli_integration.retry.max_retries  # default: 1
timeout = config.cli_integration.timeout.per_role.{ROLE}  # default: 120s

# Generate unique output file names
suffix = first 8 chars of uuidgen
gemini_prompt_file = /tmp/cli-dispatch-gemini-{ROLE}-{suffix}.txt
gemini_output_file = {FEATURE_DIR}/.dispatch-output-gemini-{ROLE}-{suffix}.txt
codex_prompt_file = /tmp/cli-dispatch-codex-{ROLE}-{suffix}.txt
codex_output_file = {FEATURE_DIR}/.dispatch-output-codex-{ROLE}-{suffix}.txt

# Write prompt files (include FILE_PATHS content inline)
WRITE {GEMINI_PROMPT} to gemini_prompt_file
WRITE {CODEX_PROMPT} to codex_prompt_file

IF state.cli.mode == "dual":
  # Launch BOTH in parallel using background Bash calls
  FOR attempt IN [1..max_retries + 1]:
    gemini_task = Bash(
      command: "{SCRIPT} --cli gemini --role {ROLE} --prompt-file {gemini_prompt_file} --output-file {gemini_output_file} --timeout {timeout}",
      run_in_background: true
    )

    codex_task = Bash(
      command: "{SCRIPT} --cli codex --role {ROLE} --prompt-file {codex_prompt_file} --output-file {codex_output_file} --timeout {timeout}",
      run_in_background: true
    )

    # Wait for both to complete, then read outputs
    gemini_exit = check gemini_task exit code
    codex_exit = check codex_task exit code
    gemini_result = Read(gemini_output_file) if gemini_exit == 0
    codex_result = Read(codex_output_file) if codex_exit == 0

    # Check metrics sidecars for diagnostics
    gemini_metrics = Read(gemini_output_file + ".metrics.json")
    codex_metrics = Read(codex_output_file + ".metrics.json")

    IF both exit codes == 0:
      BREAK
    ELSE IF attempt <= max_retries:
      LOG: "CLI {ROLE} attempt {attempt} failed — retrying"
      # Retry only the failed CLI
      CONTINUE
    ELSE:
      # Circuit breaker check
      INCREMENT state.cli.consecutive_failures
      IF state.cli.consecutive_failures >= config.cli_integration.retry.circuit_breaker_threshold:
        LOG: "Circuit breaker triggered — disabling CLI dispatch for remainder of session"
        SET state.cli.mode = "disabled"
        SKIP remaining CLI steps
      # Continue with partial results if one CLI succeeded
      IF gemini_result OR codex_result:
        LOG: "Proceeding with partial CLI results (single CLI)"
      ELSE:
        LOG: "Both CLIs failed — skipping {ROLE} step"
        SKIP

ELSE:
  # Single-CLI fallback
  cli = IF state.cli.capabilities.{PREFERRED_SINGLE_CLI} THEN "{PREFERRED_SINGLE_CLI}"
        ELSE (the other CLI)
  prompt_file = IF cli == "gemini" THEN gemini_prompt_file ELSE codex_prompt_file
  output_file = IF cli == "gemini" THEN gemini_output_file ELSE codex_output_file
  FOR attempt IN [1..max_retries + 1]:
    result_task = Bash(
      command: "{SCRIPT} --cli {cli} --role {ROLE} --prompt-file {prompt_file} --output-file {output_file} --timeout {timeout}",
      run_in_background: true
    )
    exit_code = check result_task exit code
    single_result = Read(output_file) if exit_code == 0
    IF exit_code == 0: BREAK
    ELSE IF attempt <= max_retries: CONTINUE
    ELSE:
      INCREMENT state.cli.consecutive_failures
      IF consecutive_failures >= circuit_breaker_threshold:
        SET state.cli.mode = "disabled"
      SKIP

# Clean up temporary prompt files
DELETE gemini_prompt_file, codex_prompt_file
```

### Exit Code Reference

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Read output file |
| 1 | CLI command failed | Retry or fallback |
| 2 | Timeout | Retry or fallback |
| 3 | CLI binary not found | Mark CLI unavailable, single-CLI fallback |
| 4 | No usable content (Tier 4) | Use degraded output with warning |

### Metrics Sidecar

Each dispatch writes a `.metrics.json` sidecar alongside the output file containing:
`dispatch_id`, `duration_ms`, `parse_tier`, `parse_method`, `summary_block_found`, `timed_out`, `exit_code`.

Coordinators SHOULD read the sidecar after each dispatch for KPI tracking.

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
    Apply Chain-of-Verification (CoVe) to these CLI {ROLE} findings:

    {synthesized_findings}

    Process:
    1. Generate 3-5 verification questions targeting the highest-risk findings
    2. Answer each question against the evidence provided
    3. Revise or remove findings where verification fails
    4. Return ONLY validated findings in the original output format

    Quality gate: At least 3 verification questions must pass for submission.
  """,
  description: "CoVe self-critique for CLI {ROLE}"
)
```

## Step D: Write Validated Report

```
WRITE validated findings to {FEATURE_DIR}/{REPORT_FILE}

# Reset failure counter on success
SET state.cli.consecutive_failures = 0

# Clean up dispatch output files
DELETE gemini_output_file, codex_output_file
DELETE gemini_output_file + ".metrics.json", codex_output_file + ".metrics.json"

# Execute optional post-write action
IF {POST_WRITE} defined:
  EXECUTE {POST_WRITE}
```

## Error Handling Summary

| Scenario | Behavior |
|----------|----------|
| Both CLIs succeed (exit 0) | Normal dual-CLI synthesis |
| One CLI fails, retry succeeds | Normal (delayed) |
| One CLI fails after retries | Proceed with single-CLI results |
| Both CLIs fail after retries | Skip CLI step, log warning |
| 2+ consecutive failures across phases | Circuit breaker: disable CLI dispatch for session |
| Exit code 3 (CLI not found) | Mark CLI unavailable, switch to single-CLI mode |
| Exit code 4 (Tier 4 parse failure) | Use degraded output with `flags.degraded: true` |
| Self-critique Task fails | Use unsynthesized findings with `flags.degraded: true` |
| Template deployment missing | Phase 1 detection sets `state.cli.mode = "disabled"` |
