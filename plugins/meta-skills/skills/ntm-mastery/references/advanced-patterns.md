# Advanced Patterns Reference

> **Compatibility**: ntm v1.x (March 2026)

## Context Rotation

NTM monitors token usage and automatically rotates agents before context window exhaustion, preventing workflow interruption during long sessions.

### How It Works

1. **Multiple estimation strategies** — Message counts, cumulative tokens, duration-based heuristics
2. **Warning at 80%** — Dashboard shows orange/red context bars
3. **Compaction attempt** — If `try_compact_first=true`, ntm triggers the agent's built-in compaction
4. **Rotation at 95%** — Fresh agent spawned with handoff summary if compaction insufficient
5. **Automatic recovery** — After compaction, sends recovery prompt to re-ground the agent

### Handoff Summary

When an agent rotates, ntm generates a handoff summary containing:
- Current task being worked on
- Progress made so far
- Key decisions taken
- Active files being modified
- Blockers or issues encountered

The summary is capped at `summary_max_tokens` (default 2000) and injected into the fresh agent's initial prompt.

### Post-Compaction Recovery

When compaction is detected in agent output:
1. Recovery prompt sent automatically (configurable text)
2. Bead context included if available (`include_bead_context=true`)
3. 30-second cooldown between recoveries prevents prompt spam
4. Limited to 5 recoveries per pane by default (`max_recoveries_per_pane`)

### Monitoring Context Usage

```bash
# View context usage per agent
ntm --robot-context=myapi

# Dashboard shows context bars with color coding
ntm dashboard myapi  # Press 'c' for context detail
```

### Configuration

```toml
[context_rotation]
enabled = true
warning_threshold = 0.80
rotate_threshold = 0.95
summary_max_tokens = 2000
min_session_age_sec = 300
try_compact_first = true
require_confirm = false

[context_rotation.recovery]
enabled = true
prompt = "Reread AGENTS.md so it's still fresh in your mind. Use ultrathink."
cooldown_seconds = 30
max_recoveries_per_pane = 5
include_bead_context = true
```

---

## Conflict Tracking

NTM detects when multiple agents modify the same files and classifies severity automatically.

### Detection Mechanism

1. All file modifications are logged with timestamps and agent attribution
2. Overlapping edits by multiple agents are flagged as conflicts
3. Severity classification:
   - **Warning** — Two agents edited the same file
   - **Critical** — Three or more agents edited the same file, or edits occurred within 10 minutes

### Viewing Conflicts

```bash
# Via robot snapshot
ntm --robot-snapshot --since=1h | jq '.conflicts'

# Dashboard shows conflict indicators on affected panes
# Yellow border = warning, Red border = critical
ntm dashboard myapi
```

### Conflict Payload

```json
{
  "path": "internal/api/handler.go",
  "agents": ["claude", "codex"],
  "severity": "warning",
  "first_edit": "2026-01-15T10:30:00Z",
  "last_edit": "2026-01-15T10:33:00Z"
}
```

### Preventing Conflicts

Use file reservations to proactively prevent conflicts:

```bash
ntm mail reserve myproject --agent BlueLake --paths "internal/api/*.go"
ntm mail reserve myproject --agent GreenCastle --paths "internal/auth/*.go"
```

Install the pre-commit guard to enforce reservations:

```bash
ntm hooks guard install
```

---

## Bead Management

Beads are ntm's work item system — discrete tasks with lifecycle tracking.

### Creating Beads

```bash
ntm --robot-bead-create \
  --bead-title="Fix auth bug" \
  --bead-type=bug \
  --bead-priority=1 \
  --bead-description="JWT token validation fails on expired tokens" \
  --bead-labels="auth,critical"
```

### Bead Lifecycle

```
Created → Claimed → In Progress → Closed
                 ↘ Blocked ↗
```

### Assigning Beads

```bash
# Manual assignment
ntm --robot-bead-claim=bd-42 --bead-assignee=myapi__cc_1

# Auto-assign with strategy
ntm --robot-assign=myapi --beads=bd-42,bd-45 --strategy=quality
ntm --robot-assign=myapi --auto  # No confirmation needed
```

**Assignment strategies:**
| Strategy | Behavior |
|----------|----------|
| `balanced` | Even distribution, respects agent strengths |
| `speed` | Any idle agent to any ready task |
| `quality` | Strict capability-to-task matching |
| `dependency` | Prioritize unblocking high-impact work |

### Querying Beads

```bash
ntm --robot-bead-show=bd-42
ntm --robot-bead-show=bd-42 --json
```

### Closing Beads

```bash
ntm --robot-bead-close=bd-42 --bead-close-reason="Fixed in commit abc123"
```

---

## CASS Integration (Cross-Agent Search System)

CASS indexes past conversations across multiple tools (Claude Code, Codex, Cursor, Gemini, ChatGPT) to reuse previously solved problems.

### Searching Past Conversations

```bash
# Search by keyword
ntm --robot-cass-search="authentication error" --cass-since=7d

# Get relevant context for a topic
ntm --robot-cass-context="how to implement rate limiting"

# Check CASS system status
ntm --robot-cass-status
```

### Dashboard Integration

The dashboard displays:
- Relevant past sessions matching current context
- Similarity scores for each match
- Quick access to session details

### Configuration

```toml
[cass]
default_limit = 10
include_agents = ["claude", "codex", "gemini"]
```

---

## Ensemble System

Ensembles coordinate multiple agents for structured analysis tasks (code review, architecture review, etc.).

### Configuration

```toml
[ensemble]
default_ensemble = "architecture-review"
agent_mix = "cc=3,cod=2,gmi=1"
assignment = "affinity"

[ensemble.synthesis]
strategy = "deliberative"
min_confidence = 0.50
max_findings = 10
conflict_resolution = "highlight"

[ensemble.budget]
per_agent = 5000
total = 30000
synthesis = 8000

[ensemble.early_stop]
enabled = true
min_agents = 3
findings_threshold = 0.15
similarity_threshold = 0.7
```

**Synthesis strategies:**
- `deliberative` — Agents discuss and converge on findings
- Other strategies may be available depending on ntm version

**Early stopping** terminates the ensemble when agents' findings converge (similarity above threshold) after minimum agents have reported.

---

## Checkpoint System

Save and restore session state for long-running work.

```bash
# Save checkpoint with description
ntm checkpoint save myapi -m "before refactoring auth module"

# Save with custom scrollback depth
ntm checkpoint save myapi --scrollback=500

# List checkpoints
ntm checkpoint list myapi
ntm checkpoint list myapi --json

# Show checkpoint details
ntm checkpoint show myapi cp-1
ntm checkpoint show myapi cp-1 --json

# Delete a checkpoint
ntm checkpoint delete myapi cp-1
ntm checkpoint delete myapi cp-1 -f  # Force, no confirmation
```

Use checkpoints before risky operations — killing a session, major refactors, or switching agent strategies.

---

## Profile / Persona System

Profiles assign specialized roles to agents for targeted task execution.

### Using Profiles

```bash
# Spawn with named profiles
ntm spawn myapi --profiles=architect,implementer,tester

# List available profiles
ntm profiles list
ntm profiles list --agent claude --tag backend --json

# Show profile details
ntm profiles show architect --json
```

### Profile Sets

Group profiles for common team compositions:

```toml
[[persona_sets]]
name = "backend-team"
description = "Full backend development team"
personas = ["architect", "implementer", "implementer", "tester"]

[[persona_sets]]
name = "review-panel"
description = "Code review with multiple perspectives"
personas = ["security-reviewer", "performance-reviewer", "maintainability-reviewer"]
```

### Custom Profiles

Define custom profiles to specialize agent behavior beyond the built-in set. Profiles inject system prompts that shape how agents approach tasks.
