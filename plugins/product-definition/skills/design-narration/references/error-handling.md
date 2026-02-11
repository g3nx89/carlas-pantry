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
| Discovery agent failure (no output file) | BLOCKING | Retry once. If fails: AskUserQuestion with retry / stop. |
| Discovery agent error status | BLOCKING | Present `error_reason` from discovery output. AskUserQuestion: retry selection / stop. |
| Discovery match incomplete (unmatched screens) | WARNING | Present match table to user, user decides whether to proceed or fix names. |

### Stage 2 — Screen Processing

| Error | Severity | Action |
|-------|----------|--------|
| Critique-rubric.md load failure in screen-analyzer | BLOCKING | STOP screen analysis. Do NOT proceed without self-critique — it drives all question generation. See Cross-Stage Plugin Integrity. |
| Screen analyzer crash (no summary) | BLOCKING | Reconstruct minimal summary per recovery-protocol.md. Retry once. |
| Discovery agent failure (next screen) | BLOCKING | AskUserQuestion: retry selection, skip to coherence check, or stop. |
| Screenshot capture failure | DEGRADED | Continue without screenshot. Note in narrative: "[Screenshot unavailable]". |
| Q&A answer recording failure | BLOCKING | Retry state write. If fails: present answers to user again. |
| Stall detection score tracking error | WARNING | Reset round counter to 0. Continue refinement. Log in state. |
| Context compaction (.qa-digest.md) write failure | WARNING | Fall back to full Q&A history (uncompacted). Log in state. |
| Checkpoint state write failure (mid-checkpoint) | BLOCKING | Retry state write. If fails: AskUserQuestion with options: retry / skip checkpoint / stop. |
| Lock refresh failure during checkpoint | WARNING | Continue without refresh. Log stale lock risk. |

### Stage 3 — Coherence Check

| Error | Severity | Action |
|-------|----------|--------|
| Coherence auditor crash | BLOCKING | Retry once. If fails: skip coherence, note in output, advance to Stage 4. |
| Mermaid diagram generation failure | DEGRADED | Proceed without diagrams. Note in coherence report. |

### Stage 4 — Validation

| Error | Severity | Action |
|-------|----------|--------|
| 1 MPA agent failure (after retry) | DEGRADED | Proceed with 2/3 outputs. Set `mpa_status: partial`. |
| 2-3 MPA agents failure (after retry) | BLOCKING | AskUserQuestion: proceed with partial / skip validation / stop. |
| PAL Consensus unavailable | DEGRADED | Skip PAL. Set `pal_status: skipped`. Notify user. |
| PAL < 2 models respond | DEGRADED | Set `pal_status: partial`. Proceed with available responses. |
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
