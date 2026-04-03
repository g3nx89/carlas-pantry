---
name: ntm-mastery
description: >
  This skill should be used when the user asks to "spawn agents", "launch ntm session",
  "use ntm", "manage tmux agents", "broadcast prompt to agents", "ntm dashboard",
  "ntm robot mode", "coordinate multiple Claude/Codex/Gemini agents", "ntm send",
  "ntm spawn", "ntm quick", "agent mail", "ntm palette", "ntm config",
  "multi-agent tmux", "ntm conflict tracking", "ntm context rotation",
  "ntm bead", "ntm ensemble", "ntm safety", "ntm hooks", "kill ntm session",
  "ntm status", "ntm health", "ntm checkpoint", "ntm CASS", "ntm profiles",
  "ntm work triage", "ntm assign", "ntm pipeline", "ntm serve", "ntm approve",
  "ntm timeline", "ntm audit", "ntm coordinator", "ntm locks", "ntm resume",
  "ntm recipes", "ntm workflows", "ntm extract", "ntm diff", "ntm grep",
  "ntm analytics", "ntm openapi", "ntm guards", "ntm labels",
  or when orchestrating parallel AI agents in tmux sessions via the ntm CLI.
  Also use proactively when the user is working with multiple coding agents
  and could benefit from ntm coordination patterns, even if they don't
  mention ntm by name.
version: 0.2.0
---

# NTM Mastery — Named Tmux Manager

> **Compatibility**: Verified against ntm v1.x (March 2026)
> GitHub: https://github.com/Dicklesworthstone/ntm

## Overview

NTM transforms tmux into a multi-agent command center for orchestrating Claude, Codex, and Gemini agents in parallel. It handles session lifecycle, prompt broadcasting, real-time monitoring, conflict tracking, and context rotation — eliminating the chaos of manual multi-agent coordination.

**Core capabilities:**
- **Session management**: Spawn, tile, label, and coordinate agent panes with one command
- **Prompt broadcasting**: Send tasks to specific agents or all at once
- **Work intelligence**: Graph-aware triage via `br`/`bv`, assignment strategies, human coordinator
- **Live monitoring**: Dashboard with token velocity, health states, context usage
- **Agent Mail & Locks**: Cross-session messaging, file reservations, lock management
- **Pipelines & Automation**: Multi-step workflows, recipes, templates, session presets
- **Robot mode & REST API**: JSON CLI output, local REST/SSE/WebSocket server, OpenAPI
- **Safety & Approvals**: Blocks dangerous patterns, policy rules, durable approval workflows
- **Durable state**: Checkpoints, timelines, audit trails, session resume, history search

## Quick Start

For simple tasks, use these commands directly:

**Launch agents** → `ntm spawn myproject --cc=2 --cod=1`
**Send a task** → `ntm send myproject --cc "implement the auth module"`
**Check status** → `ntm status myproject`
**Open dashboard** → `ntm dashboard myproject`
**Kill session** → `ntm kill -f myproject`

For complex workflows, load the relevant reference first.

## Command Selection Decision Tree

```
Starting a new multi-agent session?
├── YES ↓
│   Need full project scaffold with template?
│   ├── YES → ntm quick <project> --template=go|python|node|rust
│   └── NO ↓
│       Need AI agents immediately?
│       ├── YES → ntm spawn <session> --cc=N --cod=N --gmi=N [--label=NAME]
│       └── NO ↓
│           Just initialize project config?
│           ├── YES → ntm init <project>
│           └── NO → ntm create <session> --panes=N  (empty panes)
│
└── NO ↓

Triaging what to work on next?
├── YES ↓
│   Have br/bv work graph?
│   ├── YES → ntm work triage [--by-track]  |  ntm work next
│   └── NO → ntm work search "keyword"
│   Then assign: ntm assign <session> --auto --strategy=dependency
│   Read: $SKILL_PATH/references/work-intelligence.md
│
└── NO ↓

Sending work to running agents?
├── YES ↓
│   Same session, direct prompt?
│   ├── YES → ntm send <session> --cc|cod|gmi|all "prompt"
│   └── NO ↓
│       Cross-session coordination needed?
│       ├── YES → ntm mail send <project> --to <agent> "message"
│       └── NO → ntm send (with --type filter)
│
└── NO ↓

Monitoring agent progress?
├── YES ↓
│   Visual overview with token/health badges?
│   ├── YES → ntm dashboard <session>
│   └── NO ↓
│       Quick agent counts and states?
│       ├── YES → ntm status <session>
│       └── NO ↓
│           Compare agent responses or extract code?
│           ├── YES → ntm diff <s> cc_1 cod_1  |  ntm extract <s> --lang=go
│           └── NO ↓
│               Live output streaming?
│               ├── YES → ntm watch <session>
│               └── NO → ntm activity <session> --watch
│
└── NO ↓

Running multi-step automated workflows?
├── YES → ntm pipeline run .ntm/pipelines/review.yaml --session <s>
│         Read: $SKILL_PATH/references/pipelines-automation.md
└── NO ↓

Programmatic / CI/CD integration?
├── YES ↓
│   Need local server for dashboards/external services?
│   ├── YES → ntm serve --port 7337  (REST/SSE/WebSocket)
│   └── NO → Robot mode (--robot-* flags)
│   Read: $SKILL_PATH/references/robot-mode.md
│
└── NO ↓

Reviewing history, audit, or recovering state?
├── YES ↓
│   Search past sessions/prompts?
│   ├── YES → ntm history search "keyword"  |  ntm --robot-cass-search="query"
│   └── NO ↓
│       Audit trail or timeline?
│       ├── YES → ntm audit show <s>  |  ntm timeline show <id>
│       └── NO → ntm resume <s>  |  ntm checkpoint restore <s>
│   Read: $SKILL_PATH/references/pipelines-automation.md (Durable State section)
│
└── NO ↓

Need command palette or output export?
├── Palette → ntm palette <session>
└── Export → ntm copy <session> --all  |  ntm save <session> -o <dir>
```

## Quick Reference

| Command | Purpose | Key Flags |
|---------|---------|-----------|
| `spawn` | Launch agents in tiled panes | `--cc=N --cod=N --gmi=N --label=NAME` |
| `quick` | Scaffold + spawn | `--template=go\|python\|node\|rust` |
| `init` | Initialize project config | (creates `.ntm/` directory) |
| `send` | Broadcast prompt | `--cc\|cod\|gmi\|all "prompt"` |
| `dashboard` | Visual monitoring TUI | (interactive) |
| `palette` | Fuzzy command search | (interactive, F6 hotkey) |
| `status` | Agent counts/states | (quick check) |
| `health` | Health assessment | (state machine) |
| `activity` | Real-time states | `--watch` |
| `view` | Inspect session layout | (non-interactive) |
| `zoom` | Focus on specific pane | `<pane-index>` |
| `extract` | Extract code from output | `--lang=LANGUAGE` |
| `diff` | Compare agent responses | `<pane1> <pane2>` |
| `grep` | Search pane history | `"pattern" -C N` |
| `analytics` | Usage stats over time | `--days N` |
| `copy` | Export pane output | `--all --output FILE` |
| `save` | Save all to files | `-o <dir>` |
| `mail` | Cross-session messaging | `send\|inbox\|read\|ack\|reserve` |
| `locks` | File lock management | `list\|renew\|force-release` |
| `work` | Graph-aware triage | `triage\|next\|alerts\|search\|impact\|graph` |
| `assign` | Assign beads to agents | `--auto --strategy=dependency` |
| `coordinator` | Human overseer surface | `status\|digest\|conflicts` |
| `pipeline` | Multi-step workflows | `run\|status\|list\|resume\|cleanup` |
| `recipes` | Session presets | `list\|show` |
| `workflows` | Orchestration patterns | `list\|show` |
| `template` | Prompt templates | `list\|show` |
| `serve` | Local REST/WS API server | `--port N` |
| `openapi` | Generate OpenAPI spec | `generate [--stdout]` |
| `safety` | Safety system status | `status\|check\|blocked\|install` |
| `policy` | Manage safety rules | `show\|validate\|edit\|reset\|automation` |
| `approve` | Approval workflows | `list\|show\|<id>\|deny` |
| `guards` | Runtime guard management | `status\|list` |
| `checkpoint` | Save/restore state | `save\|list\|restore\|show\|delete` |
| `timeline` | Event replay | `list\|show` |
| `audit` | Audit trail | `show` |
| `history` | Session/prompt history | `search "keyword"` |
| `resume` | Resume interrupted session | (from checkpoint) |
| `interrupt` | Ctrl+C to all agents | (emergency stop) |
| `kill` | Terminate session | `-f` (force) |
| `deps` | Verify dependencies | `-v` |

## Selective Reference Loading

**Load the relevant reference only when the task requires deeper knowledge:**

```
# Session lifecycle (spawn, create, quick, init, attach, view, zoom, kill, list, labels):
Read: $SKILL_PATH/references/session-management.md

# Sending prompts, mail system, file reservations, locks, worktrees:
Read: $SKILL_PATH/references/agent-communication.md

# Dashboard, status, health, activity, extract, diff, grep, analytics, state detection:
Read: $SKILL_PATH/references/monitoring.md

# Work triage (br/bv), assignment strategies, coordinator (human overseer):
Read: $SKILL_PATH/references/work-intelligence.md

# Pipelines, recipes, workflows, templates, REST/SSE/WebSocket API, OpenAPI, durable state:
Read: $SKILL_PATH/references/pipelines-automation.md

# Robot mode JSON API (--robot-* flags):
Read: $SKILL_PATH/references/robot-mode.md

# config.toml, environment variables, palette customization, project-level .ntm/:
Read: $SKILL_PATH/references/configuration.md

# Hook system, safety policies, approvals, guards, pre-commit guard:
Read: $SKILL_PATH/references/hooks-safety.md

# Context rotation, conflicts, beads, CASS, ensembles, profiles, checkpoints, timelines, audit:
Read: $SKILL_PATH/references/advanced-patterns.md

# End-to-end workflow templates:
Read: $SKILL_PATH/references/workflows.md

# Error diagnosis and recovery:
Read: $SKILL_PATH/references/troubleshooting.md
```

## Essential Rules

1. **Pane naming convention** — Agents are named `<project>__<type>_<number>` (e.g., `myproject__cc_1` for Claude agent 1). Understand this pattern when parsing status output or targeting specific panes.

2. **Agent type shorthands** — `cc` = Claude, `cod` = Codex, `gmi` = Gemini. These appear in flags (`--cc=2`), pane names, and target filters.

3. **Session vs. project** — Session names map to project directories under `projects_base` (default `~/Developer/`). Running `ntm spawn myapi` creates agents working in `~/Developer/myapi/`.

4. **Labels for multi-swarm** — Use `--label` to run multiple swarms on the same project: `ntm spawn payments --label backend`. Without labels, re-spawning replaces the session.

5. **Robot mode vs REST API** — For local scripting and agent workflows, use `--robot-*` flags (structured JSON). For long-lived dashboards and external services, use `ntm serve` (REST/SSE/WebSocket).

6. **Mail for cross-session work** — Direct `send` works within a session. For coordination across sessions (different agent swarms on same project), use Agent Mail (`ntm mail`).

7. **File reservations + locks** — Use `ntm mail reserve` to claim paths, `ntm locks` to inspect/renew/force-release. The pre-commit guard blocks conflicting commits.

8. **Work intelligence requires br/bv** — `ntm work` commands depend on a repo with Beads/BV data. Without it, use `ntm assign` with manual bead creation.

9. **Context rotation is automatic** — NTM monitors token usage and rotates agents before context exhaustion. Configure thresholds in `config.toml` if defaults (80% warning, 95% rotate) need adjustment.

10. **Safety + approvals** — Force pushes, `rm -rf /`, and `DROP TABLE` are blocked by default. Operations marked `approval` in policy require explicit `ntm approve` before proceeding. Custom policies in `~/.ntm/policy.yaml`.

11. **Project-level config overrides** — `.ntm/` directory in project root overrides user-level `~/.config/ntm/` settings. Use for team-shared recipes, pipelines, personas, and checkpoints.

12. **Durable state by default** — Checkpoints, timelines, and audit trails persist across sessions. Use `ntm checkpoint save` before risky operations and `ntm resume` to recover.

## Shell Integration

Enable shell aliases for faster access:

```bash
eval "$(ntm shell zsh)"   # or bash/fish
```

Key aliases: `cc`/`cod`/`gmi` (launch agents), `sat` (spawn), `dash`/`d` (dashboard), `bp` (send), `ncp` (palette), `knt` (kill), `lnt` (list), `snt` (status).
