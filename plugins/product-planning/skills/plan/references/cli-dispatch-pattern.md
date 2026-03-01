# CLI Multi-CLI Dispatch Pattern

> **Canonical reference for CLI integration steps in all phases.**
> Each phase file specifies parameters; this file defines the execution pattern.
> Supports tri-CLI (gemini + codex + opencode), dual-CLI, and single-CLI modes.

## Prerequisites

Before executing this pattern, the calling phase MUST verify:

```
IF state.cli.available AND state.cli.mode != "disabled"
   AND feature_flags.cli_custom_roles.enabled
   AND {MODE_CHECK}:
  EXECUTE pattern below (mode: state.cli.mode — "tri", "dual", or "single_*")
ELSE:
  LOG: "CLI unavailable or mode mismatch — skipping {ROLE} step"
  SKIP
```

## Parameters (provided by calling phase)

| Parameter | Description |
|-----------|-------------|
| `ROLE` | CLI role name (deepthinker, planreviewer, teststrategist, securityauditor, taskauditor) |
| `PHASE_STEP` | Step number in the calling phase (e.g., 5.4, 6.2) |
| `MODE_CHECK` | Analysis mode condition (e.g., `analysis_mode in {complete, advanced}`) |
| `GEMINI_PROMPT` | Prompt text for Gemini CLI |
| `CODEX_PROMPT` | Prompt text for Codex CLI |
| `OPENCODE_PROMPT` | Prompt text for OpenCode CLI (UX/Product lens) |
| `FILE_PATHS` | Array of absolute file paths to include in prompt |
| `REPORT_FILE` | Output report path relative to `{FEATURE_DIR}/` |
| `PREFERRED_SINGLE_CLI` | Which CLI to prefer in single-CLI fallback (`gemini` or `codex`) |
| `POST_WRITE` | Optional post-write action (e.g., append to another file, merge findings) |

## Step A: Parallel Multi-CLI Dispatch (with Retry)

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
opencode_prompt_file = /tmp/cli-dispatch-opencode-{ROLE}-{suffix}.txt
opencode_output_file = {FEATURE_DIR}/.dispatch-output-opencode-{ROLE}-{suffix}.txt

# Write prompt files (include FILE_PATHS content inline)
WRITE {GEMINI_PROMPT} to gemini_prompt_file
WRITE {CODEX_PROMPT} to codex_prompt_file
WRITE {OPENCODE_PROMPT} to opencode_prompt_file

IF state.cli.mode == "tri":
  # Launch ALL THREE in parallel using background Bash calls
  FOR attempt IN [1..max_retries + 1]:
    gemini_task = Bash(
      command: "{SCRIPT} --cli gemini --role {ROLE} --prompt-file {gemini_prompt_file} --output-file {gemini_output_file} --timeout {timeout}",
      run_in_background: true
    )

    codex_task = Bash(
      command: "{SCRIPT} --cli codex --role {ROLE} --prompt-file {codex_prompt_file} --output-file {codex_output_file} --timeout {timeout}",
      run_in_background: true
    )

    opencode_task = Bash(
      command: "{SCRIPT} --cli opencode --role {ROLE} --prompt-file {opencode_prompt_file} --output-file {opencode_output_file} --timeout {timeout}",
      run_in_background: true
    )

    # Wait for all to complete, then read outputs
    gemini_exit = check gemini_task exit code
    codex_exit = check codex_task exit code
    opencode_exit = check opencode_task exit code
    gemini_result = Read(gemini_output_file) if gemini_exit == 0
    codex_result = Read(codex_output_file) if codex_exit == 0
    opencode_result = Read(opencode_output_file) if opencode_exit == 0

    # Check metrics sidecars for diagnostics
    gemini_metrics = Read(gemini_output_file + ".metrics.json")
    codex_metrics = Read(codex_output_file + ".metrics.json")
    opencode_metrics = Read(opencode_output_file + ".metrics.json")

    successful_count = COUNT(exit_code == 0 for each CLI)
    IF successful_count == 3:
      BREAK
    ELSE IF attempt <= max_retries:
      LOG: "CLI {ROLE} attempt {attempt}: {3 - successful_count} CLI(s) failed — retrying failed only"
      # Retry only the failed CLI(s)
      CONTINUE
    ELSE:
      # Circuit breaker check
      INCREMENT state.cli.consecutive_failures
      IF state.cli.consecutive_failures >= config.cli_integration.retry.circuit_breaker_threshold:
        LOG: "Circuit breaker triggered — disabling CLI dispatch for remainder of session"
        SET state.cli.mode = "disabled"
        SKIP remaining CLI steps
      # Continue with partial results if any CLI succeeded
      IF successful_count >= 1:
        LOG: "Proceeding with partial CLI results ({successful_count}/3 CLIs)"
      ELSE:
        LOG: "All CLIs failed — skipping {ROLE} step"
        SKIP

ELSE IF state.cli.mode == "dual":
  # Launch TWO available CLIs in parallel
  available_clis = [cli for cli in ["gemini", "codex", "opencode"] if state.cli.capabilities.{cli}]
  # Use first two available CLIs
  cli_a = available_clis[0], cli_b = available_clis[1]
  FOR attempt IN [1..max_retries + 1]:
    # Dispatch both available CLIs using their respective prompt/output files
    task_a = Bash(command: "{SCRIPT} --cli {cli_a} --role {ROLE} --prompt-file {cli_a}_prompt_file --output-file {cli_a}_output_file --timeout {timeout}", run_in_background: true)
    task_b = Bash(command: "{SCRIPT} --cli {cli_b} --role {ROLE} --prompt-file {cli_b}_prompt_file --output-file {cli_b}_output_file --timeout {timeout}", run_in_background: true)

    # Wait, read, retry logic same as tri-CLI but with 2 CLIs
    IF both succeed: BREAK
    ELSE IF attempt <= max_retries: retry failed CLI(s)
    ELSE: circuit breaker check, continue with partial or skip

ELSE:
  # Single-CLI fallback
  cli = IF state.cli.capabilities.{PREFERRED_SINGLE_CLI} THEN "{PREFERRED_SINGLE_CLI}"
        ELSE (first available CLI)
  prompt_file = {cli}_prompt_file
  output_file = {cli}_output_file
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
DELETE gemini_prompt_file, codex_prompt_file, opencode_prompt_file
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

### Confidence Categories

| Mode | Category | Condition | Confidence | Action |
|------|----------|-----------|------------|--------|
| Tri | Unanimous | All 3 CLIs agree | VERY HIGH | Accept finding directly |
| Tri | Majority | 2 of 3 CLIs agree | HIGH | Accept, note dissenting CLI |
| Tri | Divergent | All 3 disagree | FLAG | Escalate for user decision |
| Tri | Unique | 1 CLI only raised it | VERIFY | Cross-check against existing findings |
| Dual | Convergent | Both CLIs agree | HIGH | Accept finding directly |
| Dual | Divergent | CLIs disagree | FLAG | Escalate for user decision |
| Dual | Unique | 1 CLI only raised it | VERIFY | Cross-check against existing findings |
| Single | — | Only 1 CLI available | SINGLE | Accept with `mode: single_{cli}` marker |

### Synthesis Algorithm

```
# Collect findings from all successful CLI outputs
all_findings = []
FOR each cli_result IN [gemini_result, codex_result, opencode_result]:
  IF cli_result exists AND cli_result is not empty:
    EXTRACT findings list from cli_result
    TAG each finding with source_cli = cli_name
    APPEND to all_findings

available_cli_count = COUNT(non-empty results)

IF available_cli_count == 0:
  SKIP synthesis — no CLI data available
  RETURN empty with flags.degraded = true

# Group findings into concrete topic categories with recommendation direction
finding_groups = GROUP(all_findings) into these categories:
#   1. Architecture — structural decisions, patterns, component design
#   2. Performance — scalability, latency, resource efficiency
#   3. Security — threats, vulnerabilities, compliance
#   4. Maintainability — code quality, extensibility, technical debt
#   5. Testing — test strategy, coverage, testability
#   6. Data — schema design, data flow, storage
#   7. UX — user experience, accessibility, usability
#   8. Deployment — CI/CD, infrastructure, monitoring
#   9. Dependencies — third-party libraries, version constraints
#
# Within each category, sub-group by recommendation direction:
#   - Add/Improve — new capabilities or enhancements
#   - Remove/Reduce — simplifications or eliminations

FOR each group IN finding_groups:
  sources = UNIQUE(cli names in group)

  IF available_cli_count >= 3:
    # Tri-CLI synthesis
    IF LEN(sources) == 3:
      category = "unanimous"
      confidence = "VERY HIGH"
      merged_finding = MERGE(group findings, keep strongest evidence)
    ELSE IF LEN(sources) == 2:
      category = "majority"
      confidence = "HIGH"
      dissenter = CLI not in sources
      merged_finding = MERGE(group findings)
      merged_finding.note = "{dissenter} did not raise this finding"
    ELSE IF LEN(sources) == 1 AND all 3 CLIs raised different findings:
      category = "divergent"
      confidence = "FLAG"
      merged_finding = LIST(all 3 positions separately)
    ELSE:
      category = "unique"
      confidence = "VERIFY"
      merged_finding = group findings[0]
      merged_finding.note = "Only raised by {sources[0]} — verify against existing analysis"

  ELSE IF available_cli_count == 2:
    # Dual-CLI synthesis (reduced mode)
    IF LEN(sources) == 2:
      category = "convergent"
      confidence = "HIGH"
      merged_finding = MERGE(group findings)
    ELSE:
      category = "unique"
      confidence = "VERIFY"
      merged_finding = group findings[0]

  ELSE:
    # Single-CLI mode
    category = "single"
    confidence = "SINGLE"
    merged_finding = group findings[0]
    merged_finding.mode = "single_{sources[0]}"

  EMIT merged_finding with category, confidence

# Sort output: unanimous/convergent first, then majority, then unique, then divergent
SORT findings by confidence DESC
```

### Score Synthesis (for Consensus Roles)

For roles that produce dimensional scores (consensus, coverage validation):

```
FOR each scoring_dimension:
  scores = COLLECT(score from each CLI for this dimension)

  IF LEN(scores) >= 2:
    delta = MAX(scores) - MIN(scores)
    averaged = MEAN(scores)

    IF delta <= divergence.low:          # config: 1.0 (plan) / 5% (coverage)
      USE averaged score → HIGH confidence
    ELSE IF delta > divergence.high:     # config: 4.0 (plan) / 15% (coverage)
      FLAG for user review
      INCLUDE per-CLI score breakdown in report
    ELSE:
      USE averaged score
      NOTE disagreement in report
  ELSE:
    USE single available score
    MARK as "single-CLI score"
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
DELETE gemini_output_file, codex_output_file, opencode_output_file
DELETE gemini_output_file + ".metrics.json", codex_output_file + ".metrics.json", opencode_output_file + ".metrics.json"

# Execute optional post-write action
IF {POST_WRITE} defined:
  EXECUTE {POST_WRITE}
```

## Error Handling Summary

| Scenario | Behavior |
|----------|----------|
| All CLIs succeed (exit 0) | Normal tri/dual-CLI synthesis |
| One CLI fails, retry succeeds | Normal (delayed) |
| One CLI fails after retries | Proceed with remaining CLI results (reduced synthesis) |
| Two CLIs fail after retries | Proceed with single-CLI results |
| All CLIs fail after retries | Skip CLI step, log warning |
| 2+ consecutive failures across phases | Circuit breaker: disable CLI dispatch for session |
| Exit code 3 (CLI not found) | Mark CLI unavailable, reduce mode (tri→dual→single) |
| Exit code 4 (Tier 4 parse failure) | Use degraded output with `flags.degraded: true` |
| Self-critique Task fails | Use unsynthesized findings with `flags.degraded: true` |
| Template deployment missing | Phase 1 detection sets `state.cli.mode = "disabled"` |
