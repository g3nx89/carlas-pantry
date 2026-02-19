---
purpose: "Shared parameterized CLI dispatch, timeout, parsing, and fallback procedure"
referenced_by:
  - "stage-2-execution.md (Options H, I, J)"
  - "stage-3-validation.md (Option C)"
  - "stage-4-cli-review.md (Tier C dispatches)"
config_source: "$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml (cli_dispatch)"
---

# Shared CLI Dispatch Procedure

> **DRY extraction**: This procedure is used by 7+ integration points across Stages 2-4.
> Coordinators invoke this procedure instead of calling CLI agents directly.
> CLI agents are dispatched as standalone Bash processes using `scripts/dispatch-cli-agent.sh`.

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `prompt` | string | Full prompt with variables injected |
| `cli_name` | string | CLI identifier (e.g., "codex", "gemini") |
| `role` | string | Role name (e.g., "test_author", "correctness_reviewer") |
| `file_paths` | string[] | Directories/files the CLI agent can access |
| `timeout_ms` | int | From config `cli_dispatch.timeout_ms` (default: 300000) |
| `fallback_behavior` | string | `"native"` / `"skip"` / `"error"` |
| `fallback_agent` | string? | Agent subagent_type for native fallback (null if skip) |
| `fallback_prompt` | string? | Prompt for native fallback agent (null if skip) |
| `expected_fields` | string[] | Fields to extract from `<SUMMARY>` block |

## Procedure

### Step 1: Dispatch

Construct the composite prompt and dispatch via the Bash script:

1. Read role prompt from `$CLAUDE_PLUGIN_ROOT/config/cli_clients/{cli_name}_{role}.txt`
2. Append "## Coordinator-Injected Context" section (per Variable Injection Convention below)
3. Append "## MCP Tool Budget (Advisory)" section (per MCP Budget Injection below)
4. Write composite prompt to temp file: `{FEATURE_DIR}/.dispatch-prompt-{role}-{timestamp}.tmp`
5. Generate a short unique suffix: `{suffix}` = first 8 chars of a UUID (e.g., `$(uuidgen | cut -c1-8)`) for guaranteed filename uniqueness when multiple dispatches for the same role occur within the same second
6. Dispatch:

```
Bash("$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh \
  --cli {cli_name} \
  --role {role} \
  --prompt-file {temp_prompt_path} \
  --output-file {FEATURE_DIR}/.dispatch-output-{role}-{timestamp}-{suffix}.txt \
  --timeout {timeout_ms / 1000} \
  --expected-fields {comma_separated_fields}")
```

6. Clean up temp prompt file after dispatch completes.

### Step 2: Error Check

Check the script's exit code:

| Exit Code | Meaning | Action |
|-----------|---------|--------|
| 0 | Success (Tier 1-3 content extracted) | Parse output (Step 3) |
| 1 | CLI failed (non-transient) | GOTO **Fallback** (Step 5) |
| 2 | Timeout (SIGTERM sent, then SIGKILL after 10s) | GOTO **Fallback** (Step 5) |
| 3 | CLI binary not found | GOTO **Fallback** (Step 5) |
| 4 | Tier 4 diagnostic capture — no usable content | GOTO **Fallback** (Step 5) |

If `exit_code != 0`:
1. LOG warning: `"CLI dispatch failed: {cli_name}/{role} -- exit code {exit_code}"`
2. GOTO **Fallback** (Step 5)

### Step 3: Parse Output

Read the output file written by the dispatch script. The script has already extracted the text body from the CLI's JSON envelope (Tiers 1-2) or passed raw output (Tier 3).

1. Extract text between `<SUMMARY>` and `</SUMMARY>` delimiters
2. Parse as markdown with key-value pairs (`format_version`, then named fields)
3. For each field in `expected_fields`: extract value or set to `null`

### Step 4: Handle Parse Failures and Tier 2/3/4 Content

| Parse Tier | Content Quality | Coordinator Action |
|:---:|---|---|
| 1 | Full agent response | Parse `<SUMMARY>` normally |
| 2 | Partial response, may be truncated | Parse `<SUMMARY>` — if absent, treat entire content as "Unstructured Findings" |
| 3 | Raw CLI output with potential noise | Scan for `<SUMMARY>` — if absent, use full text as "Unstructured Findings" |
| 4 | No usable content (diagnostic only) | Go to Fallback (Step 5) — do NOT attempt `<SUMMARY>` parsing |

If parsing fails (no `<SUMMARY>` block found AND tier is 1-3):
1. LOG warning: `"CLI output parsing failed for {cli_name}/{role} (tier {N})"`
2. SET `parsed_summary = { raw_text: output_content, parsing_failed: true }`
3. Include raw text as "Unstructured Findings" in coordinator output
4. CONTINUE (do not fallback for parse-only failures on Tiers 1-3)

**Return**: `{ success: true, summary: parsed_summary, raw_output: output_content, parse_tier: N }`

### Step 5: Fallback

Execute based on `fallback_behavior`:

**`"native"`** (substitute with native agent):
```
IF fallback_agent != null:
  LOG: "Falling back to native agent: {fallback_agent}"
  result = Task(subagent_type=fallback_agent, prompt=fallback_prompt)
  RETURN { success: true, summary: parse_native_output(result), fallback: true }
```

**`"skip"`** (continue without this role's output):
```
LOG: "Skipping CLI dispatch -- continuing without {role} output"
RETURN { success: false, skipped: true }
```

**`"error"`** (halt with user prompt):
```
SET status = "needs-user-input"
SET block_reason = "CLI dispatch failed for {cli_name}/{role}: {error_details}"
RETURN { success: false, error: true }
```

## Retry Logic

If `cli_dispatch.retry.max_attempts > 0` in config:
1. On transient failure (timeout, exit_code > 1 but not 3), retry up to `max_attempts` times
2. Wait `backoff_ms` between retries
3. If all retries fail, proceed to Fallback

## Metrics Sidecar

After each dispatch, the script writes `{output_file}.metrics.json` alongside the content output. The coordinator SHOULD read this sidecar to:

1. **Populate KPI fields**: `simplification_stats`, `augmentation_bugs_found`, `uat_results` in stage summaries
2. **Log dispatch health**: `parse_tier > 1` triggers a warning in the stage log
3. **Aggregate across phases**: sum `duration_ms` and count `timed_out` for the `cli_dispatch_metrics` summary field

## Variable Injection Convention

Coordinators inject variables into CLI prompts by **appending** a context section after the role prompt text. Variables are NOT substituted in-place within the role prompt `.txt` files — the prompt files are static templates that remain unchanged at dispatch time.

The coordinator constructs the full prompt as:

```
{role prompt .txt content}

## Coordinator-Injected Context
- **Phase**: {phase_name}
- **Feature Directory**: {FEATURE_DIR}
- **Project Root**: {PROJECT_ROOT}
{...additional variables per the stage file's variable list}

## MCP Tool Budget (Advisory)
{budget from config}
```

Each stage file's integration point specifies which variables to inject. The role prompt's `## Output Format` section defines what the agent should produce; the injected context section provides the runtime values.

## MCP Budget Injection

Before dispatching, coordinators SHOULD inject the MCP tool budget from `cli_dispatch.mcp_tool_budgets` into the prompt as advisory text:

```
## MCP Tool Budget (Advisory)
- Ref: max {max_searches} searches, {max_reads} reads
- Context7: max {max_queries} queries
- Tavily: max {max_searches} searches
- Sequential Thinking: max {max_chains} chains
```

These are prompt-level guidance, not programmatic caps. CLI agents are standalone processes — they do NOT inherit Claude Code's MCP server connections. If the CLI has its own MCP support (e.g., Codex reading `.mcp.json`), the budget guides usage. If the CLI lacks MCP (Gemini), agents ignore it gracefully. Coordinators compensate by injecting pre-fetched research context into prompts (Subagent-Delegated Context Injection pattern).

## Write Boundaries

Each option's integration point specifies which directories the CLI agent may write to. The coordinator MUST verify post-dispatch that no files outside the specified boundaries were created or modified. If boundary violations are detected, log a warning and proceed (do not fail the dispatch).
