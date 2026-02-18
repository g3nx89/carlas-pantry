# CLI Dispatch Migration: PAL/clink → Process-Group-Safe Bash Dispatch

## Decision (Feb 18, 2026)

Replace PAL MCP `clink` with a Bash dispatch script using `setsid` + `timeout --kill-after` for process-group-safe CLI agent invocation. Clean rename: `clink_dispatch` → `cli_dispatch`.

## Status: Research Complete → Retrospective-Evolved (Feb 18, 2026)

Original (Feb 18): User chose "Research only — no code yet" + "Clean rename" for config keys.

**Evolution**: Analyzed the C25K narrative app retrospective (`specs/2-c25k-narrative-app/retrospective.md`, Feb 13-15 2026) — the first full execution of the implement skill with clink enabled. 6 empirical findings mapped to migration implications (see "Retrospective-Driven Evolution" section below). Key changes: dispatch instrumentation for KPI tracking, Codex output hardening, non-skippable gate config, corrected MCP access model.

## Why Replace clink

1. **Orphaned processes**: clink uses `asyncio.create_subprocess_exec` without `start_new_session=True`. `proc.kill()` hits only the direct PID. Codex/Gemini child processes (Node.js workers, etc.) survive as orphans (PPID=1), ~200MB each.
2. **Codex CLI has its own process leak issue** ([openai/codex#7932](https://github.com/openai/codex/issues/7932)). Stacking two leak vectors.
3. **PAL MCP consumes ~20% (~40K tokens) of context window** ([pal-mcp-server#255](https://github.com/BeehiveInnovations/pal-mcp-server/issues/255)).
4. **MCP overhead**: JSON-RPC layer adds latency for what are essentially one-shot subprocess dispatches.

## Retrospective-Driven Evolution

The C25K narrative app (Feb 13-15, 2026) was the first full implementation with clink dispatch enabled across Stages 2-4. The retrospective provides empirical data on dispatch reliability, metric gaps, and workflow failures that directly shape the migration.

### Evidence Map

| Finding | Retrospective Source | Migration Implication |
|---------|---------------------|----------------------|
| **Codex parse failure rate: 50%** | Section 5: "2 of 4 Codex dispatches failed parsing" in Stage 4. Both correctness reviewer and security auditor roles failed. | Dispatch script needs multi-tier parse strategy: JSON extraction → raw text fallback → structured error diagnostics (not just exit code). Current plan's exit code 4 ("JSON extraction failed") is insufficient — need to capture *what* failed and *how much* output was recovered. |
| **KPI 5.3/5.5 = null** | Section 2: simplification_stats and clink_augmentation both null despite being enabled and user-overridden. Section 5: "unclear whether executed but not tracked, or silently skipped." | Dispatch script must output a structured metrics sidecar (JSON) alongside the content output file. Coordinators read metrics for KPI reporting without parsing agent output. Addresses the "monitoring gap" — every dispatch is instrumented regardless of agent behavior. |
| **UAT via Gemini: 11 bugs in 15 scripts** | Section 11: Dedicated UAT session found 4 Critical + 4 High + 3 Medium bugs, all missed by 94 unit tests. GPS tracking (cold Flow), audio ducking (wrong focus type), navigation crash, blank screen. | Validates Tier 1 Bash dispatch for the most complex use case (mobile-mcp interactions, Genymotion Shell GPS simulation, screenshot evidence). No Tier 2 (tmux) needed for UAT — one-shot dispatch with 10-minute timeout suffices. |
| **UAT deferred under full_auto** | Section 11.3 Pattern D: Resume session had compatible device + mobile-mcp but deferred UAT alongside androidTest (T072-T075). Recommendation R-PROC-04: "UAT and Figma visual comparison should never be auto-skipped." | Add `non_skippable_gates` to config — dispatches that autonomy policy cannot skip. UAT and visual verification are user-facing quality gates requiring explicit evidence, not code-level findings that full_auto can accept/defer. |
| **MCP access model incorrect in config** *(author analysis, not retrospective finding)* | Config lines 306-308: "All clink agents share the same MCP servers as native Claude." Migration plan Section "MCP Tool Access" correctly identifies that Bash-dispatched agents lose MCP. | Must correct config comment during migration. The current comment is actively misleading — coordinators may skip MCP context injection believing agents have direct access. This is a bug even before migration. |
| **Pattern-search not performed after C1** | Section 11.3 Pattern C: Stage 4 found Critical C1 (broken data pipeline) but didn't search for same pattern across codebase. Bugs #5, #8, #9 share the same structural pattern. R-REV-01: "After finding a structural bug, search for the same pattern." | Review role prompts (`codex_correctness_reviewer.txt`, `codex_security_reviewer.txt`) must include pattern-search instructions. This is a prompt template change, not a dispatch mechanism change, but it must ship with the migration to prevent a known recurrence. |

### Priority Reassessment

Based on retrospective evidence:

| Component | Original Priority | Revised Priority | Rationale |
|-----------|:---:|:---:|-----------|
| Dispatch script (`setsid`/`timeout`) | Primary | **Primary** | Unchanged — orphan cleanup remains the core motivation |
| Dispatch instrumentation | Not planned | **P0** | 2 KPIs null → every dispatch must emit metrics |
| Codex output hardening | Implicit (exit code 4) | **P0** | 50% parse failure rate demands multi-tier recovery |
| Non-skippable gates config | Not planned | **P0** | UAT deferred under full_auto is a workflow-breaking gap |
| MCP access config correction | Noted in plan | **P0** | Active misinformation in config comments |
| Review prompt pattern-search | Not in scope | **P1** | Ships with migration to prevent known recurrence |
| UAT Tier 1 validation | Planned as Tier 1 | **Confirmed Tier 1** | Retrospective validates one-shot dispatch for UAT |

## Comparative Architecture

```
CURRENT (PAL/clink):
  Orchestrator → Task() → Coordinator → MCP tool → PAL server → asyncio subprocess → CLI
  [3 levels of nesting, MCP overhead, no process group cleanup]

PROPOSED (Tier 1 — Bash dispatch):
  Orchestrator → Task() → Coordinator → Bash() → setsid + timeout → CLI
  [2 levels of nesting, no MCP, process group cleanup via setsid]

HYPOTHETICAL (myclaude):
  Orchestrator → Task() → Coordinator → myclaude wrapper → codeagent-wrapper → CLI
  [3 levels of nesting, framework overhead, same nesting problem as clink]
```

## Why Not Use an Existing Project (myclaude, codex-orchestrator, ntm, etc.)

The ecosystem tools solve a **different problem** (multi-agent session management) than what this skill needs (one-shot headless CLI dispatch with clean process termination).

| Tool | What It Solves | Why It Doesn't Fit |
|------|---------------|-------------------|
| **myclaude** (2.3k★, AGPL-3.0) | Multi-backend orchestrator-executor | Orchestrator-within-orchestrator nesting. AGPL license incompatible with MIT plugin. 70% features unused (session resume, routing, skill modules). |
| **codex-orchestrator** (200★, MIT) | Claude→Codex job control via tmux | Codex-only (no Gemini). 13 commits, early-stage. Adds tmux dependency for one-shot dispatches. |
| **tmux-cli** (1.5k★, MIT) | tmux interaction primitives | Interaction layer, not dispatch. Still need timeout/parsing/fallback on top. Good candidate for Tier 2 (UAT). |
| **ntm** (147★, MIT) | Safety-focused tmux session manager | Session manager, not dispatch tool. Overkill for one-shot. Doesn't accept external contributions. |
| **CAO/AWS** (229★, Apache-2.0) | Supervisor/worker via FastAPI+tmux+MCP | Requires background FastAPI server. MCP-based (same overhead being eliminated). |
| **ccmanager** (v3.7.0) | Multi-CLI session management | Human-managed sessions, not programmatic dispatch. |

**When an existing tool WOULD make sense**: if the workflow evolves toward persistent interactive agents (e.g., "a Codex agent stays alive for all of Stage 2, receives tasks progressively, monitored live"). That's the Tier 2 scenario where tmux-cli or codex-orchestrator become appropriate.

## Solution: `setsid` + `timeout --kill-after`

```bash
setsid timeout --signal=TERM --kill-after=10 $TIMEOUT_SEC \
  $CLI_CMD > "$OUTPUT_FILE" 2>&1
```

- `setsid` creates new session/process group → `timeout` (without `--foreground`) sends signals to the entire process group because `$CLI_CMD` is the process group leader
- `timeout --kill-after=10` gives 10s grace between SIGTERM and SIGKILL
- Coordinators call via `Bash()` (already in their allowed-tools)
- `<SUMMARY>` output parsing unchanged — coordinators parse from output file
- **Important**: Do NOT add `--foreground` to the `timeout` call — it would bypass process group signaling

### Platform Compatibility

| Platform | `setsid` | `timeout` | Status |
|----------|----------|-----------|--------|
| **Linux** | Built-in (`util-linux`) | Built-in (`coreutils`) | Works out-of-the-box |
| **macOS (Darwin)** | Not available by default | Not available by default | Requires fallback |

The dispatch script MUST detect the platform and use the appropriate mechanism:

```bash
# Platform detection in dispatch-cli-agent.sh
if command -v setsid &>/dev/null && command -v timeout &>/dev/null; then
  # Linux path (or macOS with Homebrew coreutils + util-linux)
  setsid timeout --signal=TERM --kill-after=10 "$TIMEOUT_SEC" \
    $CLI_CMD > "$OUTPUT_FILE" 2>&1
  EXIT_CODE=$?
else
  # macOS fallback: set -m enables job control (new process group per job)
  set -m
  $CLI_CMD > "$OUTPUT_FILE" 2>&1 &
  CLI_PID=$!
  # Manual timeout with process group kill
  ( sleep "$TIMEOUT_SEC" && kill -- -$CLI_PID 2>/dev/null &&
    sleep 10 && kill -9 -- -$CLI_PID 2>/dev/null ) &
  TIMER_PID=$!
  wait $CLI_PID 2>/dev/null
  EXIT_CODE=$?
  kill $TIMER_PID 2>/dev/null
  set +m
fi
```

Alternative: `brew install coreutils util-linux` provides `gtimeout` and `gsetsid` — the script should also check for these prefixed variants: `command -v gsetsid || command -v setsid`.

### JSON Output Mode vs. `<SUMMARY>` Parsing

Codex and Gemini are invoked with JSON output flags (`--json`, `--output-format json`). This means the raw stdout is a JSON envelope, not plain text. The dispatch script handles this:

1. CLI writes JSON-wrapped output to `$OUTPUT_FILE`
2. The script extracts the text body from the JSON envelope (Codex: `.message` field; Gemini: `.response` field)
3. The coordinator parses `<SUMMARY>...</SUMMARY>` from the extracted text body — identical to current behavior

If JSON parsing fails (malformed output, CLI crash mid-stream), the script falls through to raw text parsing. The `<SUMMARY>` block may still be found in raw output since the CLI embeds it in the agent's response text.

### Codex Output Hardening (Retrospective-Driven)

> **Evidence**: C25K retrospective Stage 4 — 2 of 4 Codex dispatches (correctness reviewer, security auditor) failed to produce parseable output. Both fell back to native/raw extraction. The system recovered, but review was "less efficient than planned."

The 50% failure rate for Codex output parsing demands a multi-tier extraction strategy in the dispatch script, not just a binary JSON-or-raw fallback:

**Tier 1 — JSON envelope extraction** (happy path):
```bash
# Codex: extract .message from JSON
jq -r '.message // empty' "$RAW_OUTPUT" > "$OUTPUT_FILE" 2>/dev/null
```

**Tier 2 — Partial JSON recovery** (truncated or malformed JSON):
```bash
# If jq fails, try extracting the message value with python3 (macOS-compatible).
# Avoids grep -oP which requires Perl regex (GNU grep only, unavailable on macOS BSD grep).
python3 -c "
import re, sys
text = open(sys.argv[1]).read()
m = re.search(r'\"message\"\s*:\s*\"((?:[^\"\\\\]|\\\\.)*)\"', text, re.DOTALL)
if m:
    val = m.group(1)
    val = val.replace('\\\\n', '\n').replace('\\\\\"', '\"')
    sys.stdout.write(val)
    sys.exit(0)
sys.exit(1)
" "$RAW_OUTPUT" > "$OUTPUT_FILE"
```

**Tier 3 — Raw text with `<SUMMARY>` scan** (JSON completely absent):
```bash
# Copy raw output and let coordinator attempt <SUMMARY> extraction
cp "$RAW_OUTPUT" "$OUTPUT_FILE"
```

**Tier 4 — Diagnostic capture** (no usable content):
```bash
# Write diagnostic info to output file for coordinator error handling
cat <<DIAG > "$OUTPUT_FILE"
[DISPATCH_PARSE_FAILURE]
cli: $CLI_NAME
role: $ROLE
exit_code: $EXIT_CODE
raw_output_bytes: $(wc -c < "$RAW_OUTPUT")
raw_output_head: $(head -5 "$RAW_OUTPUT")
raw_output_tail: $(tail -5 "$RAW_OUTPUT")
DIAG
```

The dispatch script tries each tier in order, advancing to the next only when the previous produces an empty or invalid result:

```bash
# Tier cascade logic — defines "empty or invalid" for each tier
PARSE_TIER=0

# Tier 1: jq extraction
jq -r '.message // empty' "$RAW_OUTPUT" > "$OUTPUT_FILE" 2>/dev/null
if [ -s "$OUTPUT_FILE" ] && [ "$(head -c 1 "$OUTPUT_FILE")" != "{" ]; then
  PARSE_TIER=1  # Non-empty, not a nested JSON object → usable text
else
  # Tier 2: python3 partial JSON recovery
  python3 -c "..." "$RAW_OUTPUT" > "$OUTPUT_FILE" 2>/dev/null
  if [ -s "$OUTPUT_FILE" ]; then
    PARSE_TIER=2  # Non-empty → partial content recovered
  else
    # Tier 3: raw text passthrough
    cp "$RAW_OUTPUT" "$OUTPUT_FILE"
    if grep -q '<SUMMARY>' "$OUTPUT_FILE" 2>/dev/null; then
      PARSE_TIER=3  # Raw output but contains SUMMARY block → likely usable
    else
      # Tier 4: diagnostic capture — no usable content
      PARSE_TIER=4
      # (write [DISPATCH_PARSE_FAILURE] block to $OUTPUT_FILE)
    fi
  fi
fi
```

**Validity criteria per tier**: Tier 1 passes if `$OUTPUT_FILE` is non-empty (`-s`) and doesn't start with `{` (which would indicate nested JSON, not extracted text). Tier 2 passes if non-empty (python3 script exits 0 only on match). Tier 3 passes if the raw output contains a `<SUMMARY>` marker. Everything else falls to Tier 4.

The metrics sidecar (see "Dispatch Instrumentation" below) records which tier succeeded:

```json
{ "parse_tier": 1, "parse_method": "json_jq" }
{ "parse_tier": 2, "parse_method": "json_grep_partial" }
{ "parse_tier": 3, "parse_method": "raw_summary_scan" }
{ "parse_tier": 4, "parse_method": "diagnostic_capture" }
```

**Exit code update**: Exit code 4 now means "Tier 4 diagnostic capture — no usable agent output extracted" rather than the original "JSON output extraction failed." Tiers 2 and 3 still exit 0 (content was recovered, even if degraded).

**Exit code boundary**: The distinction between exit 0 (Tiers 1-3) and exit 4 (Tier 4) is whether the dispatch script produced *any content the coordinator can attempt to parse*. Tiers 1-3 all write content to `$OUTPUT_FILE` that may contain a `<SUMMARY>` block — the coordinator's parse-or-fallback logic handles quality differences. Tier 4 means the script exhausted all extraction strategies and only diagnostic metadata remains — the coordinator MUST go directly to Fallback (Step 5) without attempting `<SUMMARY>` parsing.

**Coordinator behavior per tier**:

| Parse Tier | Content Quality | Coordinator Action |
|:---:|---|---|
| 1 | Full agent response | Parse `<SUMMARY>` normally |
| 2 | Partial response, may be truncated | Parse `<SUMMARY>` — if absent, treat entire content as "Unstructured Findings" |
| 3 | Raw CLI output with potential noise | Scan for `<SUMMARY>` — if absent, use full text as "Unstructured Findings" |
| 4 | No usable content | Go to Fallback (Step 5 of dispatch procedure) |

## Dispatch Script Interface

The dispatch wrapper (`scripts/dispatch-cli-agent.sh`) is the central contract replacing `clink-dispatch-procedure.md`. All 7+ integration points across Stages 2-4 route through this script.

### Script Location

`$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh` — this introduces a new `scripts/` directory to the plugin structure (alongside existing `commands/`, `agents/`, `templates/`, `config/`). The `scripts/` directory holds executable shell scripts invoked by coordinators via `Bash()`.

### Input Parameters

```bash
dispatch-cli-agent.sh \
  --cli <codex|gemini>           # CLI to invoke
  --role <role_name>             # Role key from cli_clients/*.json
  --prompt-file <path>           # Full prompt (role prompt + injected context)
  --output-file <path>           # Where to write CLI output
  --timeout <seconds>            # From config cli_dispatch.timeout_ms / 1000
  --expected-fields <field,...>  # Comma-separated fields to extract from <SUMMARY>
```

### How Coordinators Construct the Call

```
1. Read role prompt from config/cli_clients/{cli_name}_{role}.txt
2. Append "## Coordinator-Injected Context" section (per Variable Injection Convention)
3. Append "## MCP Tool Budget (Advisory)" section (per MCP Budget Injection)
4. Write composite prompt to temp file: {FEATURE_DIR}/.dispatch-prompt-{role}-{timestamp}.tmp
5. Call Bash("$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh --cli codex --role test_author ...")
6. Read output file, parse <SUMMARY> block
7. Clean up temp prompt file
```

### Exit Codes

| Code | Meaning | Coordinator Action |
|------|---------|-------------------|
| 0 | CLI completed successfully | Parse `<SUMMARY>` from output file (Step 3 of procedure) |
| 1 | CLI failed (non-transient) | Go to Fallback (Step 5) |
| 2 | Timeout reached (SIGTERM sent, then SIGKILL after 10s) | Go to Fallback (Step 5) |
| 3 | CLI binary not found | Go to Fallback (Step 5) |
| 4 | Tier 4 diagnostic capture — no usable content extracted | Go to Fallback (Step 5) |

### Output File Format

The script writes to `--output-file`:
- On success: extracted text body from JSON envelope (ready for `<SUMMARY>` parsing)
- On Tier 2/3 recovery: partial or raw text (coordinator attempts `<SUMMARY>` parsing)
- On Tier 4 failure: diagnostic capture block (`[DISPATCH_PARSE_FAILURE]`)
- On CLI failure/timeout: stderr content (for error logging)

### Dispatch Instrumentation (Retrospective-Driven)

> **Evidence**: C25K retrospective KPIs 5.3 (simplification_stats) and 5.5 (clink_augmentation) returned `null` because the Stage 2 coordinator never reported metrics for these dispatch-dependent features. "Unclear whether these features were executed but not tracked, or silently skipped."

Every dispatch writes a **metrics sidecar** file alongside the content output file. This is the script's responsibility, not the coordinator's — ensuring instrumentation happens regardless of agent behavior or coordinator implementation gaps.

#### Sidecar Location

```
--output-file /path/to/output.txt
→ sidecar at  /path/to/output.metrics.json
```

#### Sidecar Schema

```json
{
  "dispatch_id": "uuid-v4",
  "timestamp_start": "2026-02-13T16:30:00Z",
  "timestamp_end": "2026-02-13T16:35:12Z",
  "duration_ms": 312000,
  "cli": "codex",
  "role": "test_author",
  "exit_code": 0,
  "timeout_configured_ms": 300000,
  "timed_out": false,
  "output_bytes": 24576,
  "parse_tier": 1,
  "parse_method": "json_jq",
  "summary_block_found": true,
  "platform": "darwin",
  "dispatch_method": "set_m_fallback",
  "cli_version": "codex 0.1.2504"
}
```

#### Field Descriptions

| Field | Type | Notes |
|-------|------|-------|
| `dispatch_id` | string | UUID for correlating dispatch with coordinator logs |
| `timestamp_start/end` | ISO 8601 | Wall-clock timing |
| `duration_ms` | int | End - start (includes CLI startup overhead) |
| `cli` / `role` | string | From `--cli` and `--role` flags |
| `exit_code` | int | Script exit code (0-4) |
| `timeout_configured_ms` | int | From `--timeout` flag × 1000 |
| `timed_out` | bool | True if timeout signal was sent |
| `output_bytes` | int | Size of content output file |
| `parse_tier` | int | Which extraction tier succeeded (1-4) |
| `parse_method` | string | `json_jq`, `json_grep_partial`, `raw_summary_scan`, `diagnostic_capture` |
| `summary_block_found` | bool | Whether `<SUMMARY>` was detected in the output |
| `platform` | string | `linux` or `darwin` — for tracking platform-specific issues |
| `dispatch_method` | string | `setsid_timeout` (Linux) or `set_m_fallback` (macOS) |
| `cli_version` | string | Output of `$CLI --version` (captured at dispatch start, ~0.1s overhead) |

#### Coordinator Consumption

Coordinators read the sidecar after each dispatch to:
1. **Populate KPI fields**: `simplification_stats`, `augmentation_bugs_found`, `uat_results` in stage summaries
2. **Log dispatch health**: `parse_tier > 1` triggers a warning in the stage log
3. **Aggregate across phases**: Stage 2 coordinator sums `duration_ms` and counts `timed_out` across all dispatches for the `cli_dispatch_metrics` summary field

New Stage 2 summary field:

```yaml
flags:
  cli_dispatch_metrics:
    total_dispatches: 18
    successful: 16
    failed: 2
    timed_out: 0
    avg_duration_ms: 45000
    parse_tier_distribution: { 1: 14, 2: 1, 3: 1, 4: 2 }
```

This eliminates the "null KPI" problem — even if the coordinator fails to write metrics, the sidecar files exist on disk for retrospective analysis.

## Consolidated Dispatch Script Flow

End-to-end pseudocode for `scripts/dispatch-cli-agent.sh` — consolidates platform detection, CLI invocation, 4-tier parsing, and sidecar instrumentation into a single linear flow:

```
PARSE_ARGS(--cli, --role, --prompt-file, --output-file, --timeout, --expected-fields)
RECORD start_timestamp, cli_version ($CLI --version)

# --- Platform-aware dispatch ---
IF setsid+timeout available (Linux or Homebrew):
  setsid timeout --signal=TERM --kill-after=10 $TIMEOUT $CLI_CMD > $RAW_OUTPUT 2>&1
ELSE (macOS fallback):
  set -m; $CLI_CMD > $RAW_OUTPUT 2>&1 &
  MANUAL_TIMEOUT($CLI_PID, $TIMEOUT)
  set +m

EXIT_CODE=$?
RECORD end_timestamp, duration_ms, timed_out, output_bytes

# --- 4-tier content extraction ---
TIER=0
TRY Tier 1: jq -r '.message // empty' → $OUTPUT_FILE
  IF non-empty and not nested JSON → TIER=1
ELSE TRY Tier 2: python3 partial JSON regex → $OUTPUT_FILE
  IF non-empty → TIER=2
ELSE TRY Tier 3: cp $RAW_OUTPUT → $OUTPUT_FILE
  IF contains <SUMMARY> → TIER=3
ELSE Tier 4: write [DISPATCH_PARSE_FAILURE] diagnostic → $OUTPUT_FILE
  TIER=4; EXIT_CODE=4

# --- Metrics sidecar ---
WRITE $OUTPUT_FILE.metrics.json {
  dispatch_id, timestamps, duration, cli, role,
  exit_code, parse_tier, parse_method, summary_block_found,
  platform, dispatch_method, cli_version
}

EXIT $EXIT_CODE
```

This is the implementer's reference — the sections above ("Platform Compatibility", "Codex Output Hardening", "Dispatch Instrumentation") provide detailed rationale and code snippets for each block.

## New Procedure Contract (cli-dispatch-procedure.md)

Maps the existing 5-step `clink-dispatch-procedure.md` contract to the new Bash dispatch. The parameterized interface is preserved; only the dispatch mechanism changes.

### Parameters (unchanged)

| Parameter | Type | Change from Current |
|-----------|------|-------------------|
| `prompt` | string | UNCHANGED — full prompt with variables injected |
| `cli_name` | string | UNCHANGED — "codex" or "gemini" |
| `role` | string | UNCHANGED — e.g., "test_author", "correctness_reviewer", "codebase_pattern_reviewer" |
| `file_paths` | string[] | UNCHANGED — directories/files the CLI agent can access |
| `timeout_ms` | int | Now maps to `--timeout` flag (seconds = timeout_ms / 1000) |
| `fallback_behavior` | string | UNCHANGED — "native" / "skip" / "error" |
| `fallback_agent` | string? | UNCHANGED |
| `fallback_prompt` | string? | UNCHANGED |
| `expected_fields` | string[] | UNCHANGED — passed via `--expected-fields` |

### Step Migration

| Step | Current (clink) | New (Bash dispatch) | What Changes |
|------|----------------|--------------------|----|
| **Step 1: Dispatch** | `clink(prompt, cli_name, role, file_paths)` via PAL MCP | `Bash("dispatch-cli-agent.sh --cli $cli_name --role $role ...")` | MCP call → Bash call; prompt written to temp file instead of passed inline |
| **Step 2: Error Check** | `exit_code != 0` OR MCP timeout | Script exit code (0=success, 1=fail, 2=timeout, 3=not found) | Same logic, exit codes now explicit and documented |
| **Step 3: Parse Output** | Parse `<SUMMARY>` from MCP stdout | Parse `<SUMMARY>` from output file | Read from file instead of stdout; JSON envelope already unwrapped by script |
| **Step 4: Handle Parse Failures** | UNCHANGED | UNCHANGED | Same behavior: log warning, include raw text as "Unstructured Findings" |
| **Step 5: Fallback** | UNCHANGED | UNCHANGED | Same three strategies: native / skip / error |

### Retry Logic

**Location**: Stays in the coordinator procedure (not in the dispatch script).

Rationale: The retry decision depends on context the script doesn't have (which fallback strategy to use, whether to escalate to user). The script is stateless — it dispatches once and reports the result. The coordinator owns the retry loop:

```
FOR attempt IN 1..max_attempts:
  result = Bash("dispatch-cli-agent.sh ...")
  IF result.exit_code == 0: BREAK
  IF attempt < max_attempts: WAIT backoff_ms
ELSE:
  GOTO Fallback (Step 5)
```

Config: `cli_dispatch.retry.max_attempts` (default: 1), `cli_dispatch.retry.backoff_ms` (default: 5000).

### `max_output_tokens` Field

The `max_output_tokens` field in `config/cli_clients/*.json` (e.g., 12000 for test_author, 6000 for reviewers) **becomes advisory prompt text**. There is no programmatic mechanism to limit output tokens from a headless CLI call. The coordinator injects it into the prompt:

```
## Output Budget (Advisory)
Target output: ~{max_output_tokens} tokens. Prioritize completeness over brevity, but avoid unnecessary verbosity.
```

The field remains in the JSON configs for documentation and prompt injection. It is not dead config.

## MCP Tool Access After Migration

**Key change**: Bash-dispatched CLI agents (Codex, Gemini) are standalone processes — they do NOT inherit Claude Code's MCP server connections (Ref, Context7, Tavily, Sequential Thinking, Figma, Mobile MCP).

**Impact by CLI**:

| CLI | MCP Access Post-Migration | Notes |
|-----|--------------------------|-------|
| **Codex** | Has its own MCP support (`codex exec` reads `.mcp.json`) | Must configure MCP servers in the project's `.mcp.json` or Codex's own config |
| **Gemini** | Has built-in search/grounding but NOT MCP-compatible | Loses Ref, Context7, Tavily, Sequential Thinking access |

**Resolution strategy**:

1. **MCP Budget Injection remains** — the advisory text in prompts is still useful. If agents can access MCP tools (e.g., Codex with `.mcp.json`), the budget guides usage. If agents cannot (Gemini), they ignore it gracefully.
2. **Gemini research dispatch**: For Gemini roles that relied on MCP research tools (e.g., `spec_validator` using Tavily for spec cross-validation), the coordinator should inject pre-fetched research context into the prompt instead of relying on agent-side MCP access. This aligns with the existing "Subagent-Delegated Context Injection" pattern.
3. **No changes to agent prompts**: Role prompt `.txt` files already say "Your prompt **may** include MCP-sourced context." The agent awareness hints are designed for graceful absence.

**"What Does NOT Change" correction**: Research MCP integration (Ref/Context7/Tavily) remains available to **coordinators and the orchestrator** via native Claude Code MCP. What changes is that Bash-dispatched CLI agents lose direct MCP access and must receive research context via prompt injection.

**Config comment correction (retrospective-driven)**: The current `config/implementation-config.yaml` contains an actively misleading comment at the `clink_dispatch` section header (lines 306-308): *"All clink agents (Codex, Gemini) share the same MCP servers as native Claude."* This is already incorrect for Gemini (which has no MCP support), and will be incorrect for Codex after migration (Bash-dispatched processes don't inherit MCP connections). The migration MUST correct this comment to: *"CLI agents are standalone processes without access to Claude Code's MCP servers. MCP tool budgets are injected as advisory prompt text. Coordinators compensate by pre-fetching research context via Subagent-Delegated Context Injection."* This correction is marked P0 because the misleading comment can cause coordinators to skip essential context injection.

## Process Cleanup: Gastown 3-Layer Defense-in-Depth

Reference: [steveyegge/gastown#29](https://github.com/steveyegge/gastown/issues/29)

Each orphaned CLI agent process consumes ~200MB RAM. The gold standard cleanup pattern:

**Layer 1 — Process Group Kill (at dispatch termination):**
`setsid` + `timeout --kill-after` handles this automatically. SIGTERM → 10s → SIGKILL to entire process group.

**Layer 2 — TTY-Based Kill (at session termination):**
Find all processes still attached to the terminal: `ps -eo pid,tty | grep $TTY`, kill each.

**Layer 3 — Periodic Orphan Sweep (optional background):**
```bash
ps -eo pid,ppid,args | awk '$2==1 && (/codex/ || /gemini/) && !/dispatch-cli-agent/' |
  while read PID _; do kill -9 "$PID" 2>/dev/null; done
```

For this skill, **Layer 1 alone** (via `setsid`/`timeout`) should be sufficient because all dispatches are one-shot with enforced timeouts. Layers 2-3 are insurance for edge cases.

## Stage 4 Code Review Enhancement: Plugin Integration + Gemini Leverage

### Plugin Landscape Analysis

Two code-review plugins are available in the ecosystem, each with complementary strengths:

**CEK `code-review` (v1.0.8)** — Context Engineering Kit
- 6 specialized agents: Bug Hunter (root cause tracing), Security Auditor (20-item OWASP checklist), Code Quality Reviewer (40+ checks incl. SOLID), Test Coverage Reviewer, Contracts Reviewer (API/type invariants), Historical Context Reviewer (git blame + PR history)
- **Unique value**: Confidence + Impact dual scoring with progressive filtering thresholds. Root cause tracing (5-level backward analysis). Historical context mining.
- Skill: `code-review:review-local-changes`

**Anthropic `code-review` (official)**
- 5 parallel Sonnet agents in a single command: CLAUDE.md Compliance Auditor, Bug Detector, Git History Analyzer, Previous PR Comment Analyzer, Code Comments Analyzer
- **Unique value**: CLAUDE.md-first architecture (compliance is the primary review dimension). Institutional memory via previous PR comment mining. 80+ confidence threshold for precision over recall.
- Command: `code-review:code-review` (PR-focused, posts inline GitHub comments)
- **Stage 4 compatibility**: **Not directly usable.** This plugin operates on PR diffs (`gh pr diff`, `gh pr view`) and posts inline PR comments. Stage 4 reviews local working tree changes, not a PR. The plugin's CLAUDE.md compliance, git history, and PR comment analysis patterns are valuable design inputs for Stage 4's native reviewers, but the plugin itself cannot be invoked as a Tier B review layer. It remains useful for post-implementation PR review (a separate workflow outside the implement skill).

**Overlap & Complementarity with Stage 4 Current**:

| Dimension | CEK Plugin | Anthropic Official | Stage 4 Current | Gap? |
|-----------|-----------|-------------------|-----------------|:---:|
| Bug detection | Root cause tracing (5-level) | Shallow scan + git history | Developer agent (correctness focus) | Depth |
| Security | 20-item OWASP checklist | Not explicit | Conditional Codex reviewer | Breadth |
| CLAUDE.md compliance | Via Code Quality agent | **Dedicated auditor** | Reviewer 3 (conventions, partial) | Focus |
| Git history / institutional memory | Dedicated agent | **2 agents** (blame + PR comments) | Not covered | **Yes** |
| API contracts / type invariants | **Dedicated agent** | Not explicit | Not covered | **Yes** |
| Test quality (not just count) | **Dedicated agent** | Not explicit | Stage 3 count validation only | **Yes** |
| Confidence scoring | Impact + Confidence dual | Confidence only (80+) | Severity classification only | **Yes** |
| Domain awareness (dev-skills) | No | No | Conditional reviewers | — |
| Autonomy policy + auto-fix | No | No | Full pipeline | — |
| Multi-model dispatch | No | No | Codex + Gemini via CLI | — |

**Key gaps filled by plugin integration**: Historical context, API contracts, test quality, confidence scoring. **Key gaps the plugins cannot fill**: domain-specific review (dev-skills), autonomy policy, auto-fix pipeline, multi-model dispatch.

### Integration Strategy: Three-Tier Review Architecture

Stage 4 evolves from a flat parallel review to a **three-tier architecture** where each tier adds review depth with graceful degradation:

```
Tier A — Native Claude Code Review (always runs)
  3 base developer agents + conditional domain reviewers

Tier B — Plugin-Enhanced Review (when CEK code-review plugin installed)
  6 CEK agents — adds historical context, contracts, test quality,
  confidence scoring. (Anthropic plugin is PR-focused, not Stage 4 compatible.)

Tier C — CLI-Dispatched Multi-Model Review (when CLIs available)
  Gemini: codebase-wide pattern search (1M context) + Android domain expert
  Codex: correctness + security
```

**Minimum viable review** (no CLIs, no plugins): 3 native reviewers (+ conditional domain reviewers if detected) — baseline always works.
**Maximum review depth**: 10 reviewers across 3 tiers (3 native + 2 conditional + 1 plugin + 2 Codex + 2 Gemini) with confidence-scored consolidation.

#### Tier A — Native Claude Code Review (always runs, unchanged)

- 3 base `developer` agents: Simplicity/DRY, Bugs/Correctness, Conventions/Patterns
- Conditional domain reviewers (dev-skills driven)
- These remain native because they need: deep codebase context via tool calls, dev-skills skill references, research context from Ref/Context7, integration with autonomy policy + fix pipeline

#### Tier B — Plugin-Enhanced Review (when available)

**Detection**: Check if `code-review:review-local-changes` (CEK) is listed in available skills. If not available, silently skip Tier B. (The Anthropic `code-review:code-review` plugin is PR-focused and incompatible with Stage 4's local-changes context — see Plugin Landscape Analysis above.)

**When available**, the coordinator:

1. Invokes the CEK skill via `Task(general-purpose)` to isolate context (the plugin launches 6 internal agents)
2. The plugin handles its own agent orchestration internally — the coordinator doesn't manage plugin agents
3. Plugin returns structured findings with confidence + impact scores
4. Coordinator normalizes plugin findings to Stage 4 format:
   - Confidence ≥80 + impact ≥61 → `Critical`/`High`
   - Confidence ≥75 + impact 41-60 → `Medium`
   - Below thresholds → discard
5. Normalized findings enter Stage 4's consolidation (Section 4.3) alongside Tier A/C findings
6. Deduplication merges same-issue detections across tiers (multiple sources → higher confidence)

**Why not replace Tier A with the plugin?** The plugins lack: (1) dev-skills domain references, (2) Ref/Context7 research context injection, (3) autonomy policy integration, (4) auto-fix pipeline connection, (5) conditional reviewer logic for Android/Compose/accessibility. The plugin is an augmentation layer, not a replacement.

**Breaking change from current Section 4.1**: The existing `stage-4-quality-review.md` Section 4.1 treats the code-review plugin as the **preferred path that replaces** the multi-agent review (Section 4.2 is "Fallback"). The three-tier architecture **supersedes** this design — the plugin now **augments** native review (runs in parallel as Tier B) rather than replacing it. Section 4.1 must be rewritten to reflect this change. The motivation: the plugin lacks dev-skills integration, autonomy policy, and auto-fix access, making replacement architecturally unsound.

**New review dimensions gained from plugin integration** (not in current Stage 4):

| Dimension | Source Plugin Agent | Value |
|-----------|-------------------|-------|
| Historical context | CEK: Historical Context Reviewer *(Anthropic's Git History + PR Comment Analyzers are a design reference but not directly usable — PR-focused)* | Catches recurring bugs, respects architectural decisions from git history, prevents re-introducing known issues |
| API contract validation | CEK: Contracts Reviewer | Type invariant enforcement, breaking change detection, "make illegal states unrepresentable" |
| Test quality | CEK: Test Coverage Reviewer | Meaningful assertions, boundary testing, test isolation — not just count (Stage 3) but quality |
| Root cause tracing | CEK: Bug Hunter (5-level backward analysis) | Systemic issue identification vs. flat finding reports |
| CLAUDE.md compliance | *(Design input from Anthropic plugin's dedicated CLAUDE.md Auditor pattern — incorporated into Tier A Reviewer 3's instructions)* | Explicit guideline cross-referencing (deeper than current Reviewer 3). Reviewer 3's prompt should adopt the Anthropic plugin's pattern: verify that each finding maps to an explicit CLAUDE.md/constitution.md guideline. |

#### Tier C — CLI-Dispatched Multi-Model Review (when CLIs available)

##### Gemini Strategic Reassignment

**Current assignment (suboptimal)**:
```yaml
# Current: Gemini assigned to simplicity review
clink_dispatch.stage4.multi_model_review.reviewers:
  - focus: "simplicity, DRY..."
    cli_name: "gemini"
    role: "simplicity_reviewer"
```

**Problem**: Simplicity/DRY review does NOT require a large context window — native Claude Code (with sequential file reads via tool calls) handles this well. Assigning Gemini to simplicity wastes its two unique advantages:

1. **1M token context window** — can hold the ENTIRE project in memory for cross-file pattern analysis
2. **Google/Android ecosystem training** — native understanding of Jetpack Compose, Android lifecycle, Material Design 3, Kotlin coroutines, Gradle

**Revised assignment — two leverage-optimized roles**:

**Role 1: Codebase-Wide Pattern Reviewer** (always, when Gemini available)

> Directly addresses retrospective finding R-REV-01: "After finding a structural bug, search for the same pattern across the entire codebase." In the C25K retrospective, Stage 4 found Critical C1 (broken data pipeline) but didn't search for the same pattern — missing bugs #5, #8, #9 that share the same structural issue.

| Attribute | Value |
|-----------|-------|
| Role | `codebase_pattern_reviewer` |
| CLI | Gemini |
| Context strategy | Load ENTIRE feature directory + shared modules into prompt (~100-500K tokens). Gemini's 1M window accommodates this without pagination. |
| Focus | Given Critical/High findings from Tier A/B, search the entire codebase for the same structural patterns in unreviewed files. |
| Input | Tier A/B consolidated findings (Critical + High only) + full source tree |
| Output | New finding instances matching existing patterns + pattern prevalence count |
| Dispatch timing | **Phase 2** — after Tier A/B complete (needs their findings as input) |
| Fallback | `skip` — pattern search is enhancement, not blocking |

**Why Gemini for this role**: Native Claude Code agents read files sequentially via tool calls (~0.5s per file read). Gemini with 1M context can hold 200+ files simultaneously and pattern-match across all of them in a single pass. For R-REV-01, this is an order-of-magnitude efficiency gain — the retrospective showed that sequential pattern-search simply didn't happen because it was too expensive in the review flow.

**Role 2: Android/Compose Domain Expert** (conditional: `detected_domains` includes `android`, `compose`, or `kotlin`)

| Attribute | Value |
|-----------|-------|
| Role | `android_domain_reviewer` |
| CLI | Gemini |
| Context strategy | Feature source + AndroidManifest + Gradle config + Compose theme |
| Focus | Android lifecycle correctness (ViewModel scope, `remember` vs `rememberSaveable`, `LaunchedEffect` keys), Compose performance (unnecessary recomposition, unstable parameters, `derivedStateOf` misuse), Material Design 3 compliance, Kotlin coroutine safety (`supervisorScope`, exception propagation), Gradle configuration (dependency conflicts, version catalog) |
| Dispatch timing | **Phase 1** — parallel with Tier A |
| Fallback | `skip` — native reviewers + dev-skills conditional reviewers provide baseline Android coverage |

**Why Gemini for this role**: Native training on Google's Android documentation, Jetpack libraries, and Compose APIs. Catches platform-specific anti-patterns generic reviewers miss (e.g., incorrect `StateFlow` collection in Compose, missing `Lifecycle.repeatOnLifecycle`, wrong `LazyColumn` key strategies, `@Stable` / `@Immutable` annotation requirements).

##### Codex Assignments (unchanged)

| Role | Focus | Fallback |
|------|-------|----------|
| `correctness_reviewer` | Bugs, edge cases, race conditions, data flow | Native developer |
| `security_reviewer` | OWASP Top 10 *(conditional on domains)* | Skip |
| `fix_engineer` | Auto-fix Critical/High findings | Native developer |

##### Simplicity Review Reassignment

The `gemini_simplicity_reviewer` role is **eliminated**. Simplicity review is now covered by:
- Tier A: Native Reviewer 1 (already focused on Simplicity/DRY — unchanged, better codebase integration)
- Tier B: CEK plugin's Code Quality Reviewer (40+ checks including SOLID, naming, architecture)

This is a net improvement — two specialized reviewers instead of one Gemini dispatch misaligned with its strengths.

### Revised Reviewer Dispatch Matrix

| # | Tier | Agent | CLI | Role | Focus | Phase | Fallback |
|:---:|:---:|-------|:---:|------|-------|:---:|----------|
| 1 | A | developer | Native | — | Simplicity, DRY, elegance | 1 | N/A |
| 2 | A | developer | Native | — | Bugs, correctness, edge cases | 1 | N/A |
| 3 | A | developer | Native | — | Conventions, patterns, CLAUDE.md | 1 | N/A |
| 4 | A | developer | Native | — | *(conditional)* Domain-specific | 1 | N/A |
| 5 | B | code-review skill | Plugin | — | 6-agent review (bugs, security, quality, tests, contracts, history) | 1 | Skip |
| 6 | C | Codex | CLI | `correctness_reviewer` | Bugs, data flow, race conditions | 1 | Native |
| 7 | C | Codex | CLI | `security_reviewer` | OWASP Top 10 *(conditional)* | 1 | Skip |
| 8 | C | Gemini | CLI | `android_domain_reviewer` | Android lifecycle, Compose, M3, Kotlin *(conditional)* | 1 | Skip |
| 9 | C | Gemini | CLI | `codebase_pattern_reviewer` | Cross-file pattern search for Critical/High findings | **2** | Skip |

### Dispatch Sequencing

```
Phase 1 (parallel, ~3-5 min):
  ├─ Tier A: Reviewers 1-3 (native, always) + Reviewer 4 (conditional domain)
  ├─ Tier B: Plugin review (if installed)
  ├─ Tier C: Codex correctness + security (if available)
  └─ Tier C: Gemini android_domain (if conditional + available)
      ↓
  Consolidation checkpoint: merge Phase 1 findings, extract Critical/High list
      ↓
Phase 2 (sequential, ~5-10 min — CONDITIONAL: skip if Phase 1 produced zero Critical/High findings):
  └─ Tier C: Gemini codebase_pattern_reviewer (input: Phase 1 Critical/High findings)
      ↓
Phase 3 (sequential):
  └─ Final consolidation: merge all findings, apply confidence scoring, deduplicate
      ↓
  Autonomy policy → auto-fix or escalate (unchanged)
```

The two-phase dispatch adds ~5-10 minutes (one Gemini dispatch) but addresses the retrospective's most impactful finding — missing pattern propagation across the codebase. The Phase 2 dispatch is the **only sequential dependency** in the review — everything else is parallel.

**Phase 2 conditional gate**: If Phase 1 consolidation produces zero Critical or High findings, Phase 2 is skipped entirely — there are no patterns worth searching for across the codebase. This avoids wasting 5-10 minutes on clean implementations. Configurable via `stage4.pattern_search.min_severity_trigger` (default: `"high"`).

### Confidence Scoring Adoption

Import the CEK plugin's **dual confidence+impact scoring** into Stage 4's finding consolidation (Section 4.3), applied to ALL findings regardless of tier source:

| Source | Current Scoring | Enhanced Scoring |
|--------|----------------|-----------------|
| Tier A (native) | Severity only | Severity + Confidence (estimated by consolidation agent) |
| Tier B (plugin) | Confidence + Impact (from CEK) | Pass-through (already scored) |
| Tier C (CLI) | Severity only | Severity + Confidence (estimated by consolidation agent) |

**Progressive threshold filtering** (adapted from CEK, applied post-consolidation):

| Severity | Min Confidence | Rationale |
|----------|:---:|-----------|
| Critical | 50 | Investigate even if moderately confident |
| High | 65 | Good confidence needed to warrant fix effort |
| Medium | 75 | High confidence to avoid noise |
| Low | 90 | Near-certain only (prevents nitpick accumulation) |

This replaces the binary auto-accept logic for Low/Medium findings with a more nuanced filter. Findings below the confidence threshold for their severity are **discarded before the autonomy policy applies** — the policy only sees confident findings.

**Confidence estimation heuristics for Tier A/C findings** (Tier B findings arrive pre-scored from the CEK plugin):

| Signal | Confidence Modifier | Rationale |
|--------|:---:|-----------|
| Multi-reviewer consensus (2+ reviewers flagged same issue) | +25 | Independent confirmation reduces false positive risk |
| Specific file + line reference provided | +15 | Grounded finding vs. vague observation |
| Code snippet included in finding | +10 | Reviewer examined actual code, not just file listing |
| Finding matches a known pattern from retrospective or CLAUDE.md | +10 | Established pattern, not speculative |
| Base confidence for any reported finding | 40 | Starting point — a reviewer chose to report it |

The consolidation agent sums applicable modifiers (capped at 100). Example: a finding reported by 2 reviewers with file:line and code snippet = 40 + 25 + 15 + 10 = 90 confidence. A single-reviewer vague observation = 40 confidence (below Medium threshold of 75 → discarded unless Critical/High).

### Impact on CLI Dispatch Migration

This enhancement interacts with the dispatch migration in several ways:

1. **Dispatch script**: No changes needed — the script is role-agnostic. New Gemini roles use the same `--cli gemini --role <role>` interface.
2. **Dispatch instrumentation**: Phase 2's `codebase_pattern_reviewer` receives Phase 1's **consolidated findings** (Critical/High list from the consolidation checkpoint) as input — not metrics sidecars, which contain timing/parse data only. The coordinator passes the finding list via the prompt file.
3. **Codex output hardening**: The 4-tier parse strategy applies equally to new Gemini dispatches. Gemini's `.response` field (vs. Codex's `.message`) is already handled by CLI-aware extraction.
4. **Context loading for Gemini**: The `codebase_pattern_reviewer` requires up to 800K tokens of source context. The coordinator MUST NOT read hundreds of files via `Read()` calls (would exhaust its own context). Instead, it uses `Bash()` to concatenate source files directly: `find $FEATURE_DIR -name '*.kt' -o -name '*.xml' | xargs cat > $PROMPT_TMP`. This follows the Subagent-Delegated Context Injection pattern — the coordinator orchestrates assembly without ingesting the content. The assembled file is passed via `--prompt-file` to the dispatch script.
5. **Config naming**: The new `review_plugins` and `confidence_scoring` sections are added under `cli_dispatch.stage4` (not `clink_dispatch`), born with the new naming convention.

## Files to Change (When Implementing)

### Reference Files

| File | Change |
|------|--------|
| `references/clink-dispatch-procedure.md` | Rewrite → `cli-dispatch-procedure.md`. Preserve 5-step contract + parameters (see "New Procedure Contract" above). Update frontmatter `purpose`, `config_source` to `cli_dispatch`. |
| `references/stage-1-setup.md` | Rename Section 1.7a "CLI Availability Detection (Clink)" → "CLI Availability Detection". Replace `clink` healthcheck with direct `which codex`/`which gemini` + smoke test via dispatch script. Update 10 clink references. |
| `references/stage-2-execution.md` | Rename all "Clink" references (29 occurrences): Steps 1.8, 2.1a, 3.7 dispatch calls, section headers, frontmatter `additional_references` path. Replace `clink(...)` calls with `Bash("dispatch-cli-agent.sh ...")`. |
| `references/stage-3-validation.md` | Rename Section 3.1a "Clink Spec Validator" → "CLI Spec Validator". Update 7 clink references. Replace `clink(...)` call with `Bash()` dispatch. |
| `references/stage-4-quality-review.md` | Rename Sections 4.2a, 4.4 clink references (18 occurrences): "Clink Multi-Model Review", "Clink Security Reviewer", "Clink Fix Engineer" → "CLI Multi-Model Review", etc. Replace dispatch calls. **NEW (review enhancement)**: Rewrite Section 4.1 from "plugin replaces native" to "three-tier architecture" (Tier A/B/C). Expand Section 4.2/4.2a with two-phase dispatch sequencing and revised reviewer dispatch matrix. Add plugin integration logic in Section 4.1. Add confidence scoring in Section 4.3 consolidation. Add Gemini `codebase_pattern_reviewer` Phase 2 dispatch with conditional gate. Add `android_domain_reviewer` to conditional dispatches. Remove `simplicity_reviewer` from CLI dispatch. **Section renumbering note**: Section 4.1 expands in place (no new numbered sections inserted — Tier A/B/C are subsections within 4.1). Sections 4.2-4.4 are renumbered only for clink→CLI rename, not structurally. Cross-reference grep after edit: `"Section 4.1"`, `"Section 4.2"`, `"Option D"`, `"Option E"`, `"Option F"`. **Maintainability note**: If the expanded stage-4 file exceeds 450 lines, consider extracting Tier B plugin integration and Tier C CLI review dispatch into `references/stage-4-plugin-review.md` and `references/stage-4-cli-review.md` to keep the main file under the 300-line lean orchestrator target. |
| `references/stage-6-retrospective.md` | Rename KPI "Clink Augmentation" → "CLI Augmentation" (line 90). Update YAML field `clink_augmentation_bugs` → `cli_augmentation_bugs` (line 149). |
| `references/README.md` | Update 3 tables: (1) file usage — rename `clink-dispatch-procedure.md` → `cli-dispatch-procedure.md` in usage descriptions, (2) file sizes — update filename + recalculate line count, (3) cross-references — update 14 clink references across all cross-reference entries. Add `scripts/` directory entry. |

### Config Files

| File | Change |
|------|--------|
| `config/implementation-config.yaml` | Rename top-level key `clink_dispatch` → `cli_dispatch` (11 occurrences). Rename nested refs: `per_clink_dispatch` → `per_cli_dispatch`, all comments mentioning "clink". **NEW (retro)**: Add `instrumentation` section under `cli_dispatch`. Add `non_skippable_gates` list under `cli_dispatch`. **FIX (retro P0)**: Correct the section header comment (lines 306-308) — replace "All clink agents share the same MCP servers as native Claude" with "CLI agents are standalone processes without MCP server access." **NEW (review enhancement)**: Under `stage4.multi_model_review.reviewers`, **REMOVE** the `simplicity_reviewer` Gemini entry and **REPLACE** with `codebase_pattern_reviewer` (dispatch_phase: 2). Add `android_domain_reviewer` to `conditional[]`. Add `review_plugins` and `confidence_scoring` sections under `stage4`. |
| `config/cli_clients/codex.json` | Remove `healthcheck` field (replaced by dispatch script smoke test). Keep `command`, `additional_args`, `roles`, `max_output_tokens`. Remove `timeout_seconds_override` and `retry_override` (these now live exclusively in `cli_dispatch` config). |
| `config/cli_clients/gemini.json` | Same simplification as `codex.json`. **NEW (review enhancement)**: Remove `simplicity_reviewer` from `roles` array. Add `codebase_pattern_reviewer` and `android_domain_reviewer` to `roles` array. |
| `config/cli_clients/shared/severity-output-conventions.md` | Rename "clink role prompts" → "CLI role prompts" (5 occurrences: lines 3, 15, 31, 39, 50). |
| `config/cli_clients/codex_correctness_reviewer.txt` | **NEW (retro P1)**: Add pattern-search mandate per R-REV-01: "After finding any Critical or High-severity structural bug, search the codebase for the same pattern across all similar components before concluding the review." |
| `config/cli_clients/codex_security_reviewer.txt` | **NEW (retro P1)**: Same pattern-search mandate as correctness reviewer. |
| `config/cli_clients/gemini_simplicity_reviewer.txt` | **DELETE** — simplicity review moved to native Reviewer 1 + plugin Code Quality agent. Gemini reassigned to `codebase_pattern_reviewer` and `android_domain_reviewer`. |
| `config/cli_clients/*.txt` (other) | **UNCHANGED** — role prompts are dispatch-mechanism-agnostic. |

### New Files

| File | Description |
|------|-------------|
| `scripts/dispatch-cli-agent.sh` | Process-group-safe dispatch wrapper. Platform detection (Linux `setsid`+`timeout` / macOS `set -m`+`kill -PGID`), JSON output extraction with 4-tier parse strategy (retro: Codex hardening), exit code semantics, metrics sidecar output. ~80-120 lines (expanded from ~50-80 due to multi-tier parsing and instrumentation). Must be `chmod +x`. **Runtime dependencies**: `jq` (Tier 1 JSON extraction + sidecar generation), `python3` (Tier 2 partial JSON recovery). Both are pre-installed on macOS and standard Linux; Stage 1 smoke test should verify availability. |
| `scripts/cleanup-orphans.sh` | (Optional) Gastown Layer 3 orphan sweep. Finds PPID=1 processes matching codex/gemini patterns. ~15 lines. |
| `config/cli_clients/gemini_codebase_pattern_reviewer.txt` | Role prompt for Gemini cross-file pattern analysis. Input: Critical/High findings list from Phase 1. Instructions: load entire source tree, search for same structural patterns across all files, report new instances with locations and severity. ~40 lines. |
| `config/cli_clients/gemini_android_domain_reviewer.txt` | Role prompt for Gemini Android/Compose expert review. Focus: lifecycle correctness, recomposition avoidance, Material 3 compliance, coroutine safety, Gradle configuration. ~50 lines. |

### Skill & Documentation Files

| File | Change |
|------|--------|
| `skills/implement/SKILL.md` | Rename "Clink Integration (PAL MCP)" section → "CLI Dispatch". Update Reference Map entry: `clink-dispatch-procedure.md` → `cli-dispatch-procedure.md`. Add `scripts/` to directory listing. Update 9 clink references. |
| `CLAUDE.md` (plugin) | Update architecture notes: rename `clink_dispatch` → `cli_dispatch`, update "UAT Mobile Testing Integration" section references, update development notes about config key names. Update 9 clink references. |
| `docs/workflow-diagram.md` | Rename mermaid diagram labels (15 occurrences): "clink test author" → "CLI test author", "Clink Test Augmenter" → "CLI Test Augmenter", "Clink Spec Validator" → "CLI Spec Validator", "clink fix engineer" → "CLI fix engineer", etc. |

### Files NOT Changed

The following files contain zero `clink` references and require no modifications: `references/orchestrator-loop.md`, `references/skill-resolution.md`, `references/auto-commit-dispatch.md`, `templates/*`. The `deep-research-report.md` is kept unchanged as a historical research record with original terminology.

### Retrospective-Driven Additions to Stage Reference Files

| File | Change | Source |
|------|--------|--------|
| `references/stage-2-execution.md` | **ADD** `cli_dispatch_metrics` to Stage 2 summary flags (Section 2.3). Add coordinator logic to read `.metrics.json` sidecars after each dispatch and aggregate into summary. | KPI 5.3/5.5 = null |
| `references/stage-2-execution.md` | **UPDATE** Step 3.7 (UAT Mobile Testing): Add non-skippable gate check — when `uat_mobile_tester` is in `cli_dispatch.non_skippable_gates`, the "skip to Step 4" branch MUST log `gate_status: "blocked_no_prerequisite"` instead of silently skipping. | R-PROC-04 |
| `references/stage-4-quality-review.md` | **ADD** pattern-search mandate to Section 4.2/4.2a: "After any Critical/High finding, search the codebase for the same structural pattern across all similar components." **ADD (review enhancement)**: Three-tier review architecture, plugin integration in Section 4.1, confidence scoring in Section 4.3, Gemini Phase 2 sequential dispatch, revised reviewer dispatch matrix. | R-REV-01 + review enhancement |
| `references/stage-6-retrospective.md` | **ADD** `cli_dispatch_metrics` to KPI data layer inputs. Replace null-returning KPI 5.3/5.5 logic with sidecar-based metric extraction. **ADD** sidecar cleanup: when `instrumentation.sidecar_retention` = `"session"`, delete all `.metrics.json` files after Stage 6 extracts KPI data. | KPI 5.3/5.5 = null |
| `references/agent-prompts.md` | **UPDATE** Quality Review Prompt: add pattern-search instruction block for review agents. **ADD (review enhancement)**: Plugin finding normalization instructions for consolidation agent. Confidence scoring criteria for native/CLI findings. | R-REV-01 + review enhancement |

### Total Rename Scope

14 files, ~164 occurrences of `clink`/`Clink`/`CLINK` across 4 naming patterns (plus ~15 new occurrences from retrospective-driven additions).

**Rollback strategy**: The migration should be committed as a single atomic commit (or at most 2: rename commit + new-files commit). If post-migration testing reveals dispatch failures, `git revert <commit>` restores all 14 files to pre-migration state. The `scripts/dispatch-cli-agent.sh` is additive — reverting doesn't break anything since the old `clink-dispatch-procedure.md` references are restored. The dispatch script should be tested standalone (Stage 1 smoke test) before any reference file renames.

| Pattern | Example | Replacement |
|---------|---------|-------------|
| YAML key | `clink_dispatch` | `cli_dispatch` |
| Prose title | `Clink Dispatch` | `CLI Dispatch` |
| Filename (hyphenated) | `clink-dispatch-procedure.md` | `cli-dispatch-procedure.md` |
| Inline reference | `clink` / `clink agents` | `CLI dispatch` / `CLI agents` |

## What Does NOT Change

- Orchestrator loop, stage summary contracts (schema extended but backward-compatible)
- Dev-skills integration (orchestrator-transparent)
- UAT evidence directory structure, `<SUMMARY>` parsing convention (unchanged contract, different source)
- Variable Injection Convention — coordinators still append context sections to role prompts
- Role prompt `.txt` files — mostly dispatch-mechanism-agnostic. **Exceptions**: (retro) correctness and security reviewer prompts gain pattern-search mandate (R-REV-01); (review enhancement) `gemini_simplicity_reviewer.txt` deleted, replaced by two new role files (`gemini_codebase_pattern_reviewer.txt`, `gemini_android_domain_reviewer.txt`) — these are role reassignments, not dispatch mechanism changes
- MCP Budget Injection — remains as advisory prompt text (agents may or may not have MCP access)
- Write Boundary verification — coordinator still checks post-dispatch file modifications
- Research MCP integration for **coordinators and orchestrator** (Ref/Context7/Tavily — native Claude Code MCP access is unaffected)

**Changed nuance**: Bash-dispatched CLI agents lose direct MCP server access (see "MCP Tool Access After Migration" section). Coordinators compensate by injecting pre-fetched research context into prompts.

## Tiered Approach

- **Tier 1** (primary): Bash dispatch with `setsid`/`timeout` for all one-shot dispatches
- **Tier 2** (future): tmux-cli for long-running interactive sessions requiring live monitoring
- **Tier 3** (aspirational): Claude Code Agent Teams with multi-model support

### UAT Dispatch: Tier 1 Confirmed (Retrospective-Driven)

> **Evidence**: C25K retrospective Section 11 — a dedicated UAT session executed all 15 UAT scripts via Gemini clink (`uat_mobile_tester` role) on a Genymotion Pixel 8 emulator (API 34). Results: **15/15 PASS, 11 bugs discovered and fixed** (4 Critical, 4 High, 3 Medium). The session used mobile-mcp for screen interaction, Genymotion Shell for GPS simulation, and `dumpsys audio` for audio focus verification.

The original plan identified UAT as a potential Tier 2 candidate ("tmux-cli for long-running UAT mobile testing"). The retrospective proves that **Tier 1 one-shot dispatch is sufficient** for UAT:

| Concern | Pre-Retrospective Hypothesis | Retrospective Evidence |
|---------|-----|------|
| UAT duration | "May need live monitoring" | Each UAT script completed within the 10-minute timeout (`uat_mobile_tester.timeout_ms: 600000`). No script required interactive intervention. |
| Mobile-mcp reliability | Unknown | 15/15 scripts executed successfully via `mobile_take_screenshot`, `mobile_click_on_screen_at_coordinates`, `mobile_swipe_on_screen`, `mobile_type_keys`, `mobile_list_elements_on_screen`. |
| GPS simulation | "May need real-time sensor injection" | Genymotion Shell `.gys` scripts injected GPS coordinates via `gps setlatitude/setlongitude`. App accumulated 2.26 km distance from ~50 waypoints. One-shot dispatch, no interactive session needed. |
| Evidence capture | "Screenshots as proof" | Screenshots stored to `{FEATURE_DIR}/.uat-evidence/{phase_name}/`. Evidence directory pattern works as designed. |
| Bug detection power | "Nice to have" | **11 runtime bugs found** — 4 Critical bugs that passed all 94 unit tests. UAT was the only testing level that caught these integration-level defects. The 14-hour Figma rework (Section 12) was a separate failure. |

**Tier 2 re-scoped**: tmux-cli remains relevant for scenarios requiring persistent interactive sessions (e.g., a Codex agent that stays alive for all of Stage 2, receives tasks progressively, monitored live). UAT does not need this — it is a discrete, time-bounded, evidence-producing dispatch.

**Dispatch script requirements for UAT** (no changes from current plan — all already covered):
- 10-minute timeout support (`--timeout 600`)
- Process group cleanup (agent interacting with emulator via mobile-mcp may spawn subprocesses)
- Output file for `<SUMMARY>` parsing
- Metrics sidecar for KPI 5.4 tracking (new from instrumentation section)

## Stage 1 Smoke Test

When implementing, Stage 1's CLI availability detection (currently Section 1.7a) should be upgraded from a simple `which`/`--version` check to a full dispatch smoke test:

```
1. Check: command -v codex (or gemini)
2. Write minimal prompt: "Respond with exactly: PING"
3. Run: dispatch-cli-agent.sh --cli codex --role smoke_test --prompt-file $PING_PROMPT --output-file $SMOKE_OUTPUT --timeout 30
4. Verify: output file contains "PING" (confirms dispatch + JSON extraction + output capture pipeline)
5. Write to Stage 1 summary: cli_availability.codex = true/false, cli_availability.gemini = true/false
```

This validates the full dispatch pipeline (platform detection, process group, timeout, JSON extraction, output file) before any real dispatches in Stages 2-4.

## Key CLI Flags for Headless Dispatch

| CLI | Command | Flags | Notes |
|-----|---------|-------|-------|
| **Codex** | `codex exec` | `--json -C $PROMPT_FILE` | Headless, JSON output. `codex fork` does NOT support headless. |
| **Gemini** | `gemini` | `--non-interactive --yolo --output-format json` | Headless, JSON output. `--yolo` skips confirmation prompts. |

The `--json` / `--output-format json` flags wrap the agent's text response in a JSON envelope. The dispatch script extracts the text body before writing to the output file, so coordinators see plain text with `<SUMMARY>` blocks — identical to current behavior.

## Config Schema After Migration

The `cli_dispatch` config section preserves the same structure as `clink_dispatch` (just renamed), with three retrospective-driven additions (`instrumentation`, `non_skippable_gates`, corrected MCP comment) and three code-review-enhancement additions (`stage4.review_plugins`, `stage4.confidence_scoring`, revised `stage4.multi_model_review.reviewers`).

```yaml
# BEFORE (current)
clink_dispatch:
  timeout_ms: 300000
  retry:
    max_attempts: 1
    backoff_ms: 5000
  mcp_tool_budgets:
    per_clink_dispatch:
      ref: { max_searches: 3, max_reads: 2 }
      # ...

# AFTER (renamed + evolved)
cli_dispatch:
  timeout_ms: 300000
  retry:
    max_attempts: 1
    backoff_ms: 5000

  # NEW (retrospective): Dispatch instrumentation — every dispatch writes a metrics sidecar.
  # Addresses KPI 5.3/5.5 = null in C25K retro (metrics never tracked).
  instrumentation:
    enabled: true                     # Write .metrics.json sidecar alongside output file
    capture_cli_version: true         # Run $CLI --version before dispatch (~0.1s overhead)
    sidecar_retention: "session"      # "session" = delete after Stage 6; "permanent" = keep forever

  # NEW (retrospective): Non-skippable dispatch gates — dispatches that autonomy policy cannot skip.
  # Addresses R-PROC-04: "UAT and Figma visual comparison should never be auto-skipped."
  # When a dispatch is listed here, even full_auto policy MUST execute it and produce evidence.
  # If the dispatch fails or is unavailable (CLI missing, device missing), the coordinator logs
  # the failure with evidence ("attempted, failed because: {reason}") — never silently skips.
  non_skippable_gates:
    - "stage2.uat_mobile_tester"      # UAT acceptance testing — requires explicit evidence
    # Future: "stage2.figma_visual_verification" when R-VIS-01 is implemented

  # RENAMED: per_clink_dispatch → per_cli_dispatch
  # CORRECTED COMMENT: CLI agents do NOT share MCP servers with native Claude.
  # Bash-dispatched agents are standalone processes without MCP access.
  # These budgets are injected as advisory prompt text. If the CLI has its own MCP support
  # (e.g., Codex reading .mcp.json), the budget guides usage. If the CLI lacks MCP (Gemini),
  # agents ignore the budget gracefully. Coordinators compensate by injecting pre-fetched
  # research context into prompts (Subagent-Delegated Context Injection pattern).
  mcp_tool_budgets:
    per_cli_dispatch:
      ref: { max_searches: 3, max_reads: 2 }
      # ...

  # --- Stage 4 Code Review Enhancement (plugin + Gemini leverage) ---
  # NOTE: Tier A native reviewers (Reviewers 1-3) are configured via the existing
  # `quality_review.focus_areas` and `quality_review.agent_count` config keys
  # (not repeated here). The `stage4` section below configures Tier B (plugins)
  # and Tier C (CLI dispatch) ONLY. Conditional domain reviewers are configured
  # via `dev_skills.conditional_review`.

  stage4:
    multi_model_review:
      enabled: true
      reviewers:
        # CHANGED: Gemini reassigned from simplicity → codebase-wide pattern analysis
        - focus: "Cross-file structural pattern search for Critical/High findings"
          cli_name: "gemini"
          role: "codebase_pattern_reviewer"
          dispatch_phase: 2          # Runs after Tier A/B findings available
          context_strategy: "full_source_tree"
          max_context_tokens: 800000  # Cap at 800K — leaves room for prompt + output
          fallback_behavior: "skip"
        - focus: "bugs, functional correctness, edge cases, race conditions"
          cli_name: "codex"
          role: "correctness_reviewer"
          dispatch_phase: 1
          fallback_behavior: "native"
        - focus: "conventions, pattern adherence, CLAUDE.md compliance"
          cli_name: null              # Always native
          role: null
          dispatch_phase: 1
      conditional:
        - focus: "security vulnerabilities, OWASP Top 10"
          cli_name: "codex"
          role: "security_reviewer"
          domains: ["api", "web_frontend", "database"]
          dispatch_phase: 1
          fallback_behavior: "skip"
        # NEW: Gemini Android/Compose domain expert
        - focus: "Android lifecycle, Compose performance, Material 3, Kotlin coroutines"
          cli_name: "gemini"
          role: "android_domain_reviewer"
          domains: ["android", "compose", "kotlin"]
          dispatch_phase: 1
          fallback_behavior: "skip"
      fix_engineer:
        enabled: true
        cli_name: "codex"
        role: "fix_engineer"
        fallback_to_native: true

    # NEW: Plugin integration — augment native review with code-review plugin agents.
    # NOTE: `review_plugins` is under `cli_dispatch.stage4` for config co-location with
    # other Stage 4 review enhancements, even though plugins are not CLI dispatches.
    # Alternative location would be `quality_review.plugins` — kept here to group all
    # three-tier review config (Tier A in quality_review, Tier B/C here) under one stage4 block.
    review_plugins:
      enabled: true
      preferred_skill: "code-review:review-local-changes"  # CEK (6 agents, confidence scoring)
      # No fallback_skill: Anthropic's code-review:code-review is PR-focused (uses gh pr diff),
      # incompatible with Stage 4's local-changes context. If CEK not installed, Tier B is skipped.
      invoke_via: "task"              # Isolate in Task(general-purpose) — prevents plugin's 6 internal agents from consuming coordinator context
      confidence_mapping:             # Maps plugin output to Stage 4 severity
        critical_min_confidence: 80
        critical_min_impact: 81
        high_min_confidence: 65
        high_min_impact: 61
        medium_min_confidence: 75
        medium_min_impact: 41
      max_findings_from_plugin: 20    # Cap to prevent overwhelming consolidation

    # NEW: Phase 2 conditional gate — skip codebase pattern search if no high-severity findings
    pattern_search:
      min_severity_trigger: "high"    # Phase 2 dispatches only if Phase 1 has >= 1 finding at this level or above
      # "critical" = only on critical findings; "high" = critical or high; "medium" = always (not recommended)

    # NEW: Confidence scoring — progressive threshold filtering for all tiers
    confidence_scoring:
      enabled: true
      thresholds:                     # Findings below min_confidence for their severity are discarded
        critical: 50
        high: 65
        medium: 75
        low: 90
```

### Non-Skippable Gates: Design Rationale

> **Evidence**: C25K retrospective Pattern D — the resume session had a compatible Pixel 8 emulator and mobile-mcp tools but deferred all 15 UAT scripts alongside androidTest tasks. The autonomy policy (`full_auto`) treated UAT as a deferrable finding rather than a mandatory quality gate. This allowed the implementation to be declared "complete" with 0/15 acceptance criteria validated, masking 11 runtime bugs that required 4+ hours to fix later.

The `non_skippable_gates` list identifies dispatch types that represent **user-facing quality evidence**, not code-level findings. The distinction:

| Category | Example | Autonomy Policy Behavior |
|----------|---------|--------------------------|
| Code finding | "Variable naming inconsistency" | Policy decides: fix, defer, or accept |
| Quality gate | "UAT acceptance test execution" | Policy CANNOT skip — must execute and produce evidence |

When a gate dispatch is listed in `non_skippable_gates`:
1. The coordinator MUST attempt the dispatch regardless of autonomy policy
2. If prerequisites are met (CLI available, device available) → dispatch runs normally
3. If prerequisites are NOT met → coordinator logs `"Gate '{gate}' BLOCKED: {reason}"` with explicit evidence of the blocker, and sets `gate_status: "blocked_no_prerequisite"` in the summary
4. The coordinator NEVER silently skips a gate dispatch — either it runs, or the skip is loudly documented

This does NOT change how gate *findings* are handled — a UAT finding at Medium severity is still subject to the autonomy policy's `findings.medium` action. What changes is that the dispatch itself cannot be elided.

All nested structure (`stage2`, `stage3`, `stage4`) is preserved. `mcp_tool_budgets` survives the rename because it controls prompt-level guidance, not MCP dispatch plumbing.

Skill version bump: `SKILL.md` version should increment (e.g., 2.3.0 → 3.0.0) to reflect the dispatch mechanism change + Stage 4 three-tier review architecture.

## Key Research Sources

- C25K narrative app retrospective: `specs/2-c25k-narrative-app/retrospective.md` (Feb 13-15, 2026) — first full execution with clink enabled, 21 bugs found, 6 dispatch-relevant findings
- CEK code-review plugin: `~/.claude/plugins/marketplaces/context-engineering-kit/plugins/code-review/` (v1.0.8) — 6-agent parallel review with confidence+impact scoring, root cause tracing, historical context mining
- Anthropic code-review plugin: `~/.claude/plugins/marketplaces/claude-plugins-official/plugins/code-review/` — 5-agent review with CLAUDE.md compliance auditing, PR comment analysis, 80+ confidence threshold
- Deep research report: `deep-research-report.md` (in plugin root)
- Gastown 3-layer orphan cleanup: https://github.com/steveyegge/gastown/issues/29
- PAL context consumption: https://github.com/BeehiveInnovations/pal-mcp-server/issues/255
- MCP SDK subprocess fix: https://github.com/modelcontextprotocol/python-sdk/pull/555
- Codex headless: `codex exec` works; `codex fork` does NOT support headless ([#11750](https://github.com/openai/codex/issues/11750))
- Gemini headless: https://geminicli.com/docs/cli/headless/
- CPython asyncio subprocess issue: https://github.com/python/cpython/issues/88050

## Ecosystem Tools Worth Monitoring

| Tool | Why |
|------|-----|
| claude-code-tools/tmux-cli (1.5k★) | Tier 2 candidate for UAT long-running sessions |
| ntm v1.7.0 (147★) | Best safety features (thundering herd, approval gates, checkpoint restore) |
| ccmanager v3.7.0 | Devcontainer support for security isolation without Docker overhead |
| codex-orchestrator (200★) | Claude→Codex job control if persistent sessions needed |
| Claude Code Agent Teams | Watch for multi-model support (currently Claude-only) |
