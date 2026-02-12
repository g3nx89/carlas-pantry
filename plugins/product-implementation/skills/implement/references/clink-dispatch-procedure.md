---
purpose: "Shared parameterized clink dispatch, timeout, parsing, and fallback procedure"
referenced_by:
  - "stage-2-execution.md (Options H, I)"
  - "stage-3-validation.md (Option C)"
  - "stage-4-quality-review.md (Options D, E, F)"
config_source: "$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml (clink_dispatch)"
---

# Shared Clink Dispatch Procedure

> **DRY extraction**: This procedure is used by 7+ integration points across Stages 2-4.
> Coordinators invoke this procedure instead of calling clink directly.

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `prompt` | string | Full prompt with variables injected |
| `cli_name` | string | CLI identifier (e.g., "codex", "gemini") |
| `role` | string | Role name (e.g., "test_author", "simplicity_reviewer") |
| `file_paths` | string[] | Directories/files the CLI agent can access |
| `timeout_ms` | int | From config `clink_dispatch.timeout_ms` (default: 300000) |
| `fallback_behavior` | string | `"native"` / `"skip"` / `"error"` |
| `fallback_agent` | string? | Agent subagent_type for native fallback (null if skip) |
| `fallback_prompt` | string? | Prompt for native fallback agent (null if skip) |
| `expected_fields` | string[] | Fields to extract from `<SUMMARY>` block |

## Procedure

### Step 1: Dispatch

Invoke clink via PAL MCP:

```
clink(prompt=prompt, cli_name=cli_name, role=role, absolute_file_paths=file_paths)
```

Apply timeout from `timeout_ms` (default 5 minutes from config).

### Step 2: Error Check

If `exit_code != 0` OR timeout exceeded:
1. LOG warning: `"Clink dispatch failed: {cli_name}/{role} -- {stderr or 'timeout'}"`
2. GOTO **Fallback** (Step 5)

### Step 3: Parse Output

Parse `stdout` for `<SUMMARY>...</SUMMARY>` block:
1. Extract text between `<SUMMARY>` and `</SUMMARY>` delimiters
2. Parse as markdown with key-value pairs (`format_version`, then named fields)
3. For each field in `expected_fields`: extract value or set to `null`

### Step 4: Handle Parse Failures

If parsing fails (no `<SUMMARY>` block found OR required fields missing):
1. LOG warning: `"Clink output parsing failed for {cli_name}/{role}"`
2. SET `parsed_summary = { raw_text: stdout, parsing_failed: true }`
3. Include raw text as "Unstructured Findings" in coordinator output
4. CONTINUE (do not fallback for parse-only failures)

**Return**: `{ success: true, summary: parsed_summary, raw_output: stdout }`

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
LOG: "Skipping clink dispatch -- continuing without {role} output"
RETURN { success: false, skipped: true }
```

**`"error"`** (halt with user prompt):
```
SET status = "needs-user-input"
SET block_reason = "Clink dispatch failed for {cli_name}/{role}: {error_details}"
RETURN { success: false, error: true }
```

## Retry Logic

If `clink_dispatch.retry.max_attempts > 0` in config:
1. On transient failure (timeout, exit_code > 1 but not 127), retry up to `max_attempts` times
2. Wait `backoff_ms` between retries
3. If all retries fail, proceed to Fallback

## Variable Injection Convention

Coordinators inject variables into clink prompts by **appending** a context section after the role prompt text. Variables are NOT substituted in-place within the role prompt `.txt` files — the prompt files are static templates that remain unchanged at dispatch time.

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

Before dispatching, coordinators SHOULD inject the MCP tool budget from `clink_dispatch.mcp_tool_budgets` into the prompt as advisory text:

```
## MCP Tool Budget (Advisory)
- Ref: max {max_searches} searches, {max_reads} reads
- Context7: max {max_queries} queries
- Tavily: max {max_searches} searches
- Sequential Thinking: max {max_chains} chains
```

These are prompt-level guidance, not programmatic caps.

## Write Boundaries

Each option's integration point specifies which directories the clink agent may write to. The coordinator MUST verify post-dispatch that no files outside the specified boundaries were created or modified. If boundary violations are detected, log a warning and proceed (do not fail the dispatch).
