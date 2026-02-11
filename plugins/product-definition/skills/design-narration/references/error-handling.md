---
stage: all
artifacts_written: []
---

# Error Handling

> Shared reference for error recovery and graceful degradation across all Design Narration stages.
> All error paths follow the same taxonomy, logging format, and escalation rules.

## CRITICAL RULES (must follow)

1. **Never silently swallow errors**: Every error is logged to the state file workflow log and surfaced to the orchestrator.
2. **Graceful degradation over hard failure**: If a non-critical component fails, continue with reduced functionality and notify user.
3. **Coordinator errors always return summary**: Even on failure, coordinators write a summary with `status: error` and `error_reason`.

---

## Error Taxonomy

| Severity | Definition | Orchestrator Action |
|----------|-----------|---------------------|
| **FATAL** | Cannot continue workflow (Figma MCP unavailable, state file corrupt) | STOP workflow, notify user, preserve state |
| **BLOCKING** | Stage cannot advance (agent crash, required file missing) | Retry once, then present options via AskUserQuestion |
| **DEGRADED** | Feature unavailable but workflow continues (PAL unavailable, 1 MPA agent failed) | Skip/fallback, notify user, log in state |
| **WARNING** | Non-critical issue detected (truncated context, stale patterns) | Log to state, continue without user interruption |

---

## Logging Format

Append to the markdown body (below YAML frontmatter) of the state file:

```markdown
### {ISO_TIMESTAMP} - ERROR [{SEVERITY}]
- **Stage**: {STAGE_NUMBER} - {STAGE_NAME}
- **Component**: {agent_name | tool_name | "orchestrator"}
- **Error**: {ERROR_MESSAGE}
- **Action Taken**: {retry | skip | fallback | stop}
- **User Notified**: yes | no
```

---

## Cross-Stage — Plugin Integrity

These errors can occur in any stage when plugin reference files or config are needed.

| Error | Severity | Action |
|-------|----------|--------|
| Plugin reference file unreadable (critique-rubric.md, screen-processing.md, etc.) | BLOCKING | STOP current stage. Report exact file path. Suggest: `claude plugins remove product-definition && claude plugins add <path>`. |
| Config file missing or unparseable | FATAL | STOP workflow. Report parse error or missing file. |
| Template file unreadable (ux-narrative-template.md, screen-narrative-template.md) | BLOCKING | STOP current stage. Report missing template path. Plugin reinstall required. |

---

## Per-Stage Error Handling

### Stage 1 — Setup

| Error | Severity | Action |
|-------|----------|--------|
| Figma MCP unavailable | FATAL | STOP. Notify user to open Figma Desktop with plugin. |
| Config validation failure | FATAL | STOP. Report missing/invalid key. |
| Lock conflict (non-stale) | BLOCKING | AskUserQuestion: override or cancel. |
| Context document unreadable | WARNING | Skip context doc, notify user, continue. |

### Stage 2 — Screen Processing

| Error | Severity | Action |
|-------|----------|--------|
| Critique-rubric.md load failure in screen-analyzer | BLOCKING | STOP screen analysis. Do NOT proceed without self-critique — it drives all question generation. See Cross-Stage Plugin Integrity. |
| Screen analyzer crash (no summary) | BLOCKING | Reconstruct minimal summary per recovery-protocol.md. Retry once. |
| Figma selection unreadable | BLOCKING | AskUserQuestion: retry selection or skip screen. |
| Screenshot capture failure | DEGRADED | Continue without screenshot. Note in narrative: "[Screenshot unavailable]". |
| Q&A answer recording failure | BLOCKING | Retry state write. If fails: present answers to user again. |
| Stall detection score tracking error | WARNING | Reset round counter to 0. Continue refinement. Log in state. |
| Context compaction (.qa-digest.md) write failure | WARNING | Fall back to full Q&A history (uncompacted). Log in state. |
| Checkpoint state write failure (mid-checkpoint) | BLOCKING | Retry state write. If fails: AskUserQuestion with options: retry / skip checkpoint / stop. |
| Lock refresh failure during checkpoint | WARNING | Continue without refresh. Log stale lock risk. |

### Stage 2-BATCH — File-Based Handoff Errors (Step 2B.6 Parallel Refinement)

| Error | Severity | Action |
|-------|----------|--------|
| Task completion timeout (single screen) | BLOCKING | Auto-retry once. If still timed out: mark screen status as "pending" for retry in next cycle. Log timeout duration, screen name, and retry attempt. Continue collecting remaining tasks. |
| Summary file missing after completion signal | BLOCKING | Agent returned "DONE" but summary file not found on disk. Mark screen "pending" for retry. Log discrepancy. |
| YAML frontmatter invalid or missing required fields | BLOCKING | Summary file exists but frontmatter unparseable. Mark screen "pending" for retry. Log parse error. |
| All tasks timed out (zero completions) | FATAL | AskUserQuestion: "All parallel refinement tasks failed. Retry all / Stop workflow". Preserve all prior work. |

### Stage 3 — Coherence Check

| Error | Severity | Action |
|-------|----------|--------|
| Coherence auditor crash | BLOCKING | Retry once. If fails: skip coherence, note in output, advance to Stage 4. |
| Mermaid diagram generation failure | DEGRADED | Proceed without diagrams. Note in coherence report. |
| Clink tool unavailable (`mcp__pal__clink` not in tool set) | DEGRADED | Fall back to digest-first strategy. Log as DEGRADED. |
| Gemini CLI error (clink dispatch fails) | DEGRADED | Fall back to digest-first strategy. Log error details. |
| Coherence report missing/malformed after clink | DEGRADED | Delete malformed file. Fall back to digest-first strategy. |
| Clink timeout (exceeds `coherence.clink_timeout_seconds`) | DEGRADED | Fall back to digest-first strategy. Log timeout duration. |

### Stage 4 — Validation

| Error | Severity | Action |
|-------|----------|--------|
| 1 MPA agent failure (after retry) | DEGRADED | Proceed with 2/3 outputs. Set `mpa_status: partial`. |
| 2-3 MPA agents failure (after retry) | BLOCKING | AskUserQuestion: proceed with partial / skip validation / stop. |
| PAL Consensus unavailable | DEGRADED | Skip PAL. Set `pal_status: skipped`. Notify user. |
| PAL < 2 models respond | DEGRADED | Set `pal_status: partial`. Proceed with available responses. |
| Clink/Codex implementability dispatch failure | DEGRADED | Fall back to Task subagent dispatch. Log clink error. |
| Clink/Codex output file missing after return | DEGRADED | Fall back to Task subagent dispatch. Log file absence. |
| Clink/Codex output malformed (frontmatter invalid or missing required fields) | DEGRADED | Delete malformed file. Fall back to Task subagent dispatch. |
| Clink/Codex timeout (exceeds `validation.mpa.clink_implementability.timeout_seconds`) | DEGRADED | Fall back to Task subagent dispatch. Log timeout duration. |
| Synthesis agent crash | BLOCKING | Retry once. If fails: present raw MPA outputs to user. |

### Stage 5 — Output Assembly

| Error | Severity | Action |
|-------|----------|--------|
| Screen narrative file missing | BLOCKING | Skip screen in output. Note gap. Warn user. |
| Coherence report missing | DEGRADED | Assemble without coherence notes section. |
| Validation synthesis missing | DEGRADED | Assemble without validation summary section. Note gap. |
| Write failure (disk full, permissions) | FATAL | STOP. Notify user. State preserved for retry. |

---

## PAL Failure Notification Format

When a PAL model fails during the multi-step consensus workflow, the orchestrator logs:

```
+-----------------------------------------------------------+
| WARNING: PAL CONSENSUS STEP FAILURE                        |
+-----------------------------------------------------------+
| Model:     {MODEL_ALIAS}                                   |
| Stance:    {MODEL_STANCE}                                  |
| Stage:     4 - Validation                                  |
| Step:      {STEP_NUMBER} of {TOTAL_STEPS}                  |
| Operation: consensus (multi-step)                          |
| Error:     {ERROR_MESSAGE}                                 |
|                                                            |
| Models responded: {RESPONDED} of {TOTAL_MODELS}            |
| Minimum required: {MIN} (per validation.pal_consensus)     |
| Continuation ID: {CONTINUATION_ID or "not yet assigned"}   |
+-----------------------------------------------------------+
```

When PAL is entirely unavailable (not just a single model failure):

```
+-----------------------------------------------------------+
| INFO: PAL CONSENSUS SKIPPED                                |
+-----------------------------------------------------------+
| Stage:     4 - Validation                                  |
| Reason:    PAL MCP tools unavailable                       |
| Fallback:  MPA results only (no multi-model consensus)     |
| Status:    validation.pal_status set to "skipped"          |
+-----------------------------------------------------------+
```

---

## Self-Verification

After any error recovery:

1. State file updated with error log entry
2. No orphan artifacts (partial files cleaned up)
3. User notified of any degraded functionality
4. `current_stage` reflects actual progress (not optimistic)

## CRITICAL RULES REMINDER

1. Never silently swallow errors
2. Graceful degradation over hard failure
3. Coordinator errors always return summary with `status: error`
