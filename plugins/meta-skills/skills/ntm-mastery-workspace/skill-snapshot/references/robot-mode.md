# Robot Mode Reference

> **Compatibility**: ntm v1.x (March 2026)

Robot mode provides structured JSON output for programmatic integration, CI/CD pipelines, and agent-to-agent coordination. All robot commands output a standard JSON envelope.

## JSON Envelope Format

Every robot response follows this structure:

```json
{
  "success": true,
  "timestamp": "2026-01-27T07:00:00Z",
  "version": "1.0.0",
  "output_format": "json",
  "error": null,
  "error_code": null,
  "hint": null,
  "_meta": {
    "duration_ms": 42,
    "exit_code": 0,
    "command": "robot-status"
  }
}
```

**Exit codes:**
- `0` — Success
- `1` — Error
- `2` — Unavailable (e.g., session doesn't exist)

## Inspection Commands

### `--robot-status`

Sessions and agent state overview.

```bash
ntm --robot-status
ntm --robot-status --json  # Force JSON output
```

### `--robot-context=SESSION`

Token usage per agent — essential for monitoring context window consumption.

```bash
ntm --robot-context=myapi
ntm --robot-context=myapi --json
```

### `--robot-snapshot`

Unified session state (sessions + beads + alerts + mail) in one call.

```bash
ntm --robot-snapshot
ntm --robot-snapshot --since=1h  # Filter by recency
```

The most comprehensive single query — use when building monitoring dashboards.

### `--robot-tail=SESSION`

Recent pane output with configurable line limits.

```bash
ntm --robot-tail=myapi --lines=50
ntm --robot-tail=myapi --panes=1,2 --lines=20
```

**Flags:**
- `--lines=N` — Lines per pane (default 20)
- `--panes=1,2,3` — Filter specific pane indices

### `--robot-inspect-pane=SESSION`

Detailed inspection of a specific pane.

```bash
ntm --robot-inspect-pane=myapi --panes=1
```

### `--robot-files=SESSION`

File changes with agent attribution — shows which agent modified which files.

```bash
ntm --robot-files=myapi
```

### `--robot-metrics=SESSION`

Export session metrics (durations, token counts, velocities).

```bash
ntm --robot-metrics=myapi
```

### `--robot-palette`

Query the command palette entries as JSON.

```bash
ntm --robot-palette
```

### `--robot-dashboard`

Dashboard summary in markdown or JSON.

```bash
ntm --robot-dashboard
ntm --robot-dashboard --json
```

### `--robot-terse`

Single-line encoded state — minimal tokens, ideal for LLM context injection.

```bash
ntm --robot-terse
```

### `--robot-health`

Project health summary.

```bash
ntm --robot-health
```

### `--robot-version`

Version information.

```bash
ntm --robot-version
```

## Control Commands

### `--robot-send=SESSION`

Send prompts to agents programmatically.

```bash
ntm --robot-send=myapi --msg="Implement the auth module" --type=claude
ntm --robot-send=myapi --msg="Run all tests" --type=all
```

**Flags:**
- `--msg="prompt"` — The prompt text
- `--type=claude|codex|gemini|all` — Target agent type

### `--robot-ack=SESSION`

Watch for agent responses (blocking wait with timeout).

```bash
ntm --robot-ack=myapi --ack-timeout=30s
```

### `--robot-spawn=SESSION`

Create a session programmatically.

```bash
ntm --robot-spawn=myapi --spawn-cc=2 --spawn-cod=1
```

### `--robot-interrupt=SESSION`

Send Ctrl+C to all agents.

```bash
ntm --robot-interrupt=myapi
```

### `--robot-assign=SESSION`

Assign beads (work items) to agents.

```bash
ntm --robot-assign=myapi --beads=bd-1,bd-2
ntm --robot-assign=myapi --auto  # Auto-assign without confirmation
ntm --robot-assign=myapi --strategy=quality
```

**Assignment strategies:**
- `balanced` (default) — Even distribution, respects agent strengths
- `speed` — Maximize throughput, any idle agent to any ready task
- `quality` — Strict capability-to-task matching
- `dependency` — Prioritize high-impact unblocking work

### `--robot-replay=SESSION`

Replay a previous command.

```bash
ntm --robot-replay=myapi --replay-id=cmd-42
```

## Bead Management

Beads are ntm's work item system — discrete tasks that can be created, assigned, tracked, and closed.

### `--robot-bead-create`

```bash
ntm --robot-bead-create \
  --bead-title="Fix auth bug" \
  --bead-type=bug \
  --bead-priority=1 \
  --bead-description="JWT token validation fails on expired tokens" \
  --bead-labels="auth,critical"
```

### `--robot-bead-show=BEAD_ID`

```bash
ntm --robot-bead-show=bd-42
ntm --robot-bead-show=bd-42 --json
```

### `--robot-bead-claim=BEAD_ID`

```bash
ntm --robot-bead-claim=bd-42 --bead-assignee=myapi__cc_1
```

### `--robot-bead-close=BEAD_ID`

```bash
ntm --robot-bead-close=bd-42 --bead-close-reason="Fixed in commit abc123"
```

## Mail (Robot Mode)

```bash
ntm --robot-mail
```

Returns mail state as JSON — inboxes, unread counts, reservations.

## CASS (Cross-Agent Search)

```bash
# Search past conversations
ntm --robot-cass-search="authentication error" --cass-since=7d

# Get context for a topic
ntm --robot-cass-context="how to implement rate limiting"

# CASS system status
ntm --robot-cass-status
```

## Alerts (Robot Mode)

```bash
# View active alerts
ntm --robot-alerts

# Include resolved alerts
ntm --robot-alerts --include-resolved

# Dismiss a specific alert
ntm --robot-dismiss-alert=ALERT_ID

# Dismiss all alerts
ntm --robot-dismiss-alert --dismiss-all
```

## Session State

```bash
# Save session state to file
ntm --robot-save=myapi --save-output=/path/state.json

# Restore from state file (dry run first)
ntm --robot-restore=mystate --restore-dry

# Command history with statistics
ntm --robot-history=myapi --history-stats

# Token usage grouped by model
ntm --robot-tokens --tokens-group-by=model
```

## Output Control Flags

These flags modify output across all robot commands:

| Flag | Values | Purpose |
|------|--------|---------|
| `--robot-format` | `json\|toon\|auto` | Output format |
| `--robot-verbosity` | `terse\|default\|debug` | Detail level |
| `--panes` | `1,2,3` | Filter pane indices |
| `--type` | `claude\|codex\|gemini` | Filter agent type |
| `--lines` | `N` | Lines per pane (default 20) |
| `--json` | (flag) | Force JSON output |

## Integration Pattern: Claude Code → ntm

When using ntm from within Claude Code (via Bash tool), prefer robot mode for parseable output:

```bash
# Check agent status before sending work
status=$(ntm --robot-status --json)

# Send a task and wait for acknowledgment
ntm --robot-send=myapi --msg="Fix the failing test" --type=claude
ntm --robot-ack=myapi --ack-timeout=60s

# Check what files were modified
ntm --robot-files=myapi --json
```
