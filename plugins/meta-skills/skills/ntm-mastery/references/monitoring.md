# Monitoring Reference

> **Compatibility**: ntm v1.x (March 2026)

## Commands

### `ntm dashboard <session>`

Interactive visual dashboard with real-time pane monitoring.

```bash
ntm dashboard myapi
```

**Dashboard elements:**
- Visual pane grid with color-coded agent cards
- Live agent counts (Claude, Codex, Gemini, user panes)
- Token velocity badges (tokens-per-minute per agent)
- Animated status indicators with pulsing selection
- Context usage bars with color coding
- Conflict indicators on affected panes

**Keyboard navigation:**
| Key | Action |
|-----|--------|
| `↑/↓` or `j/k` | Navigate panes |
| `1-9` | Quick select pane |
| `z` or `Enter` | Zoom to pane |
| `r` | Refresh pane data |
| `c` | View context info |
| `m` | Access Agent Mail |
| `?` | Help overlay |
| `Esc/q` | Quit |

**Context usage visualization (color thresholds):**
- Green: < 40% usage
- Yellow: 40-60% usage
- Orange: 60-80% usage
- Red: > 80% usage (warning threshold, rotation imminent)

**Responsive layout tiers:**
| Terminal Width | Layout |
|---------------|--------|
| < 120 cols | Stacked, minimal badges |
| 120-199 cols | List/detail split view |
| 200-239 cols | Secondary metadata, wider gutters |
| 240-319 cols | Tertiary labels/variants/locks |
| ≥ 320 cols | Richest metadata display |

### `ntm status <session>`

Quick snapshot of agent counts and pane details.

```bash
ntm status myapi
```

Shows session name, pane count, agent types with names, and current states.

### `ntm activity <session>`

Real-time activity state monitoring.

```bash
# One-time snapshot
ntm activity myapi

# Continuous monitoring (updates in place)
ntm activity myapi --watch
```

**Flags:**
- `--watch` — Continuous refresh mode

### `ntm health <session>`

Agent health assessment using the state machine.

```bash
ntm health myapi
```

Reports per-agent health state: HEALTHY, DEGRADED, RATE_LIMITED, or UNHEALTHY.

### `ntm watch <session>`

Stream agent output in real time.

```bash
ntm watch myapi
```

Displays live terminal output from all agent panes. Useful for observing agent behavior without attaching to the tmux session.

### `ntm palette <session>`

Fuzzy-searchable command palette TUI.

```bash
ntm palette myapi
```

**Navigation:**
| Key | Action |
|-----|--------|
| `↑/↓` or `j/k` | Navigate commands |
| `1-9` | Quick select |
| `Enter` | Execute command |
| `Esc` | Close |
| Type text | Filter/search |
| `Ctrl+P` | Pin command |
| `Ctrl+F` | Favorite command |
| `?/F1` | Help overlay |

The palette includes built-in commands and custom entries from `config.toml`.

## State Detection

NTM infers agent states by analyzing terminal output patterns — no agent instrumentation needed.

**Detected states:**

| State | Meaning |
|-------|---------|
| `WAITING` | Agent idle, awaiting input |
| `GENERATING` | Actively producing output |
| `THINKING` | Processing (extended thinking mode) |
| `ERROR` | Error detected in output |
| `STALLED` | No output for extended period |

**Velocity estimation:**
- Measured in characters/second using exponential smoothing
- Displayed as token velocity badges in the dashboard
- Sudden velocity drops may indicate agent is stuck or rate-limited

**Detection configuration** (in `config.toml`):

```toml
[detection]
capture_lines = 20          # Lines analyzed per poll
poll_interval_ms = 500      # Polling frequency
stall_threshold_sec = 300   # Seconds before STALLED state

[detection.patterns.claude]
idle = ["claude>", "Claude >", "❯"]
error = ["Error:", "rate_limit", "context_length_exceeded"]

[detection.patterns.codex]
idle = ["codex>", "$ "]
error = ["Failed", "API Error"]
```

## Alerting State Machine

Health tracking with debounced state transitions to prevent alert storms.

**State transitions:**
```
HEALTHY ↔ DEGRADED ↔ RATE_LIMITED
          ↓
      UNHEALTHY
```

- **HEALTHY** → Normal operation, responsive agents
- **DEGRADED** → Slow responses detected
- **RATE_LIMITED** → API rate limit hit
- **UNHEALTHY** → No response for extended period

**Alert types:**
`unhealthy`, `degraded`, `rate_limited`, `restart`, `restart_failed`, `max_restarts`, `recovered`

**Alert payload example:**
```json
{
  "timestamp": "2026-01-15T10:30:00Z",
  "type": "unhealthy",
  "session": "myproject",
  "pane_id": "myproject__cc_1",
  "agent_type": "claude",
  "prev_state": "degraded",
  "new_state": "unhealthy",
  "message": "Agent claude degraded → unhealthy",
  "suggestion": "Check agent logs. May need restart."
}
```

See `configuration.md` for alerting and notification channel setup.

## Output Export

### `ntm copy <session>`

Export pane output to clipboard or file.

```bash
# Copy all agent output to clipboard
ntm copy myapi --all

# Copy Claude agents' output to a file
ntm copy myapi --cc --output /tmp/claude-output.txt

# Copy specific agent type
ntm copy myapi --cod --output /tmp/codex-output.txt
```

**Flags:**
- `--cc|cod|gmi|all` — Agent type filter
- `--output FILE` — Write to file instead of clipboard

### `ntm save <session>`

Save all pane outputs to timestamped files in a directory.

```bash
ntm save myapi -o /tmp/session-outputs/
```

Creates one file per pane with timestamps in filenames.

**Key distinction:** `copy` extracts to clipboard (default) or single file; `save` writes all panes to separate timestamped files in a directory.
