# Configuration Reference

> **Compatibility**: ntm v1.x (March 2026)

## Configuration File

Optional config at `~/.config/ntm/config.toml`. NTM works with sensible defaults if this file doesn't exist.

## Core Settings

```toml
# Base directory for project working directories
# Sessions create subdirectories here: ~/Developer/<session-name>/
projects_base = "~/Developer"
```

## Agent Commands

Define how each agent type is launched:

```toml
[agents]
claude = '{{memLimitPrefix}} claude --dangerously-skip-permissions'
codex = "codex --dangerously-bypass-approvals-and-sandbox -m gpt-5.1-codex-max"
gemini = "gemini --yolo"
```

`{{memLimitPrefix}}` is a template variable ntm resolves at runtime for memory-constrained environments.

## Tmux Settings

```toml
[tmux]
default_panes = 10       # Default pane count for `ntm create`
palette_key = "F6"       # Hotkey for command palette
```

## Command Palette

Define custom palette commands accessible via `ntm palette`:

```toml
[[palette]]
key = "fresh_review"
label = "Fresh Eyes Review"
category = "Quick Actions"
prompt = "Take a step back and carefully reread recent code changes..."

[[palette]]
key = "git_commit"
label = "Commit Changes"
category = "Quick Actions"
prompt = "Commit all changed files with detailed messages and push."

[[palette]]
key = "fix_linting"
label = "Fix Linting"
category = "Code Quality"
prompt = "Review and fix all linting errors in the codebase."
```

**Fields:**
- `key` — Unique identifier
- `label` — Display name in palette UI
- `category` — Grouping category (Quick Actions, Code Quality, Coordination, Architecture, Testing, Documentation, Bug Fix, Refactor)
- `prompt` — The prompt sent to the selected agent

**Dynamic prompt fields:**
```toml
prompt = "Implement {{.Feature}} with {{.Style}} coding style"
```

## Ensemble Configuration

Control multi-agent ensemble behavior:

```toml
[ensemble]
default_ensemble = "architecture-review"
agent_mix = "cc=3,cod=2,gmi=1"
assignment = "affinity"
mode_tier_default = "core"
allow_advanced = false

[ensemble.synthesis]
strategy = "deliberative"       # How results are combined
min_confidence = 0.50
max_findings = 10
include_raw_outputs = false
conflict_resolution = "highlight"

[ensemble.cache]
enabled = true
ttl_minutes = 60
cache_dir = "~/.cache/ntm/context-packs"
max_entries = 32
share_across_modes = true

[ensemble.budget]
per_agent = 5000               # Token budget per agent
total = 30000                  # Total budget across all agents
synthesis = 8000               # Budget for synthesis step
context_pack = 2000            # Budget for context packs

[ensemble.early_stop]
enabled = true
min_agents = 3
findings_threshold = 0.15
similarity_threshold = 0.7
window_size = 3
```

## Context Rotation

Automatic context window management:

```toml
[context_rotation]
enabled = true
warning_threshold = 0.80        # Yellow alert at 80%
rotate_threshold = 0.95         # Rotate agent at 95%
summary_max_tokens = 2000       # Handoff summary size limit
min_session_age_sec = 300       # Don't rotate young sessions
try_compact_first = true        # Attempt compaction before rotation
require_confirm = false         # Auto-rotate without asking

[context_rotation.recovery]
enabled = true
prompt = "Reread AGENTS.md so it's still fresh in your mind. Use ultrathink."
cooldown_seconds = 30           # Minimum gap between recoveries
max_recoveries_per_pane = 5     # Limit per pane
include_bead_context = true     # Include active bead in recovery prompt
```

## Notifications

Multi-channel notification system:

```toml
[notifications]
enabled = true
events = ["agent.error", "agent.crashed", "agent.rate_limit"]

[notifications.desktop]
enabled = true
title = "NTM"

[notifications.webhook]
enabled = false
url = "https://hooks.slack.com/services/..."
method = "POST"
template = '{"text": "NTM: {{.Type}} - {{jsonEscape .Message}}"}'

[notifications.webhook.headers]
Authorization = "Bearer token"

[notifications.shell]
enabled = false
command = "/path/to/handler.sh"
pass_json = true

[notifications.log]
enabled = true
path = "~/.config/ntm/notifications.log"
```

## Alerting

Health monitoring with debounced alerts:

```toml
[alerting]
enabled = true
debounce_interval_sec = 60      # Minimum gap between same-type alerts
alert_on = ["unhealthy", "rate_limited", "restart", "restart_failed", "max_restarts"]
```

## CASS (Cross-Agent Search)

```toml
[cass]
default_limit = 10
include_agents = ["claude", "codex", "gemini"]
```

## History and Events

```toml
[history]
enabled = true
path = "~/.config/ntm/history.jsonl"
max_entries = 10000
retention_days = 90

[events]
enabled = true
path = "~/.config/ntm/events.jsonl"
max_file_size_mb = 50
retention_days = 30
```

## State Detection

Customize how ntm detects agent states:

```toml
[detection]
capture_lines = 20              # Lines analyzed per poll
poll_interval_ms = 500          # Polling frequency
stall_threshold_sec = 300       # Seconds before STALLED state

[detection.patterns.claude]
idle = ["claude>", "Claude >", "❯"]
error = ["Error:", "rate_limit", "context_length_exceeded"]

[detection.patterns.codex]
idle = ["codex>", "$ "]
error = ["Failed", "API Error"]
```

## Scanner (Auto-Scanner / UBS)

```toml
[scanner]
enabled = true
ubs_path = ""
debounce_ms = 1000
timeout_seconds = 60

[scanner.defaults]
timeout = "60s"
exclude = [".git", "node_modules", "vendor", ".beads"]

[scanner.dashboard]
show_findings = true
max_display = 10
```

## Redaction

Automatic secret detection and redaction in agent communication:

```toml
[redaction]
mode = "warn"                   # off | warn | redact | block
scan_sends = true
scan_copies = true
scan_saves = true
scan_exports = true

[[redaction.patterns]]
name = "openai_key"
pattern = "sk-proj-[A-Za-z0-9_-]{20,}"
type = "api_key"
severity = "critical"

[[redaction.patterns]]
name = "github_token"
pattern = "ghp_[A-Za-z0-9_]{36}"
type = "auth_token"
severity = "critical"
```

**Redaction modes:**
- `off` — No scanning
- `warn` — Log warning but allow
- `redact` — Replace with `[REDACTED]`
- `block` — Prevent the operation entirely

## Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `NTM_PROJECTS_BASE` | Override projects_base | `~/Code` |
| `NTM_THEME` | UI color theme | `auto\|mocha\|macchiato\|latte\|nord\|plain` |
| `NTM_ICONS` | Icon set | `nerd\|unicode\|ascii` |
| `NTM_PROFILE` | Enable startup profiling | `1` |
| `NTM_REDUCE_MOTION` | Disable animations | `1` |

**Performance tips:**
- `NTM_PROFILE=1` — Profile startup and command execution times
- `NTM_REDUCE_MOTION=1` — Disable animations for slower terminals
- `NTM_ICONS=ascii` — Use ASCII icons if font rendering is problematic
