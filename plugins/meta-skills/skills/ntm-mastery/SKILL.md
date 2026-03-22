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
  or when orchestrating parallel AI agents in tmux sessions via the ntm CLI.
  Also use proactively when the user is working with multiple coding agents
  and could benefit from ntm coordination patterns, even if they don't
  mention ntm by name.
version: 0.1.0
---

# NTM Mastery — Named Tmux Manager

> **Compatibility**: Verified against ntm v1.x (March 2026)
> GitHub: https://github.com/Dicklesworthstone/ntm

## Overview

NTM transforms tmux into a multi-agent command center for orchestrating Claude, Codex, and Gemini agents in parallel. It handles session lifecycle, prompt broadcasting, real-time monitoring, conflict tracking, and context rotation — eliminating the chaos of manual multi-agent coordination.

**Core capabilities:**
- **Session management**: Spawn, tile, and coordinate agent panes with one command
- **Prompt broadcasting**: Send tasks to specific agents or all at once
- **Live monitoring**: Dashboard with token velocity, health states, context usage
- **Agent Mail**: Cross-session messaging and file reservations to prevent conflicts
- **Robot mode**: Full JSON API for programmatic integration and CI/CD
- **Safety system**: Blocks dangerous patterns (force push, rm -rf, DROP TABLE)

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
│       ├── YES → ntm spawn <session> --cc=N --cod=N --gmi=N
│       └── NO → ntm create <session> --panes=N  (empty panes)
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
│           Live output streaming?
│           ├── YES → ntm watch <session>
│           └── NO → ntm activity <session> --watch
│
└── NO ↓

Programmatic / CI/CD integration?
├── YES → Robot mode (--robot-* flags)
│         Read: $SKILL_PATH/references/robot-mode.md
└── NO ↓

Need command palette or output export?
├── Palette → ntm palette <session>
└── Export → ntm copy <session> --all  |  ntm save <session> -o <dir>
```

## Quick Reference

| Command | Purpose | Key Flags |
|---------|---------|-----------|
| `spawn` | Launch agents in tiled panes | `--cc=N --cod=N --gmi=N` |
| `quick` | Scaffold + spawn | `--template=go\|python\|node\|rust` |
| `send` | Broadcast prompt | `--cc\|cod\|gmi\|all "prompt"` |
| `dashboard` | Visual monitoring TUI | (interactive) |
| `palette` | Fuzzy command search | (interactive, F6 hotkey) |
| `status` | Agent counts/states | (quick check) |
| `health` | Health assessment | (state machine) |
| `activity` | Real-time states | `--watch` |
| `copy` | Export pane output | `--all --output FILE` |
| `save` | Save all to files | `-o <dir>` |
| `mail` | Cross-session messaging | `send\|inbox\|read\|ack\|reserve` |
| `interrupt` | Ctrl+C to all agents | (emergency stop) |
| `kill` | Terminate session | `-f` (force) |
| `deps` | Verify dependencies | `-v` |

## Selective Reference Loading

**Load the relevant reference only when the task requires deeper knowledge:**

```
# Session lifecycle (spawn, create, quick, attach, kill, list):
Read: $SKILL_PATH/references/session-management.md

# Sending prompts, mail system, file reservations:
Read: $SKILL_PATH/references/agent-communication.md

# Dashboard, status, health, activity, state detection:
Read: $SKILL_PATH/references/monitoring.md

# Robot mode JSON API (--robot-* flags):
Read: $SKILL_PATH/references/robot-mode.md

# config.toml, environment variables, palette customization:
Read: $SKILL_PATH/references/configuration.md

# Hook system, safety policies, pre-commit guard:
Read: $SKILL_PATH/references/hooks-safety.md

# Context rotation, conflicts, beads, CASS, ensembles, profiles:
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

4. **Robot mode for automation** — Any command that another tool or script needs to consume should use `--robot-*` flags, which output structured JSON. Human-facing commands use the standard TUI.

5. **Mail for cross-session work** — Direct `send` works within a session. For coordination across sessions (different agent swarms on same project), use Agent Mail (`ntm mail`).

6. **File reservations prevent conflicts** — Before assigning file-heavy tasks to multiple agents, use `ntm mail reserve` to claim paths. The pre-commit guard blocks conflicting commits.

7. **Context rotation is automatic** — NTM monitors token usage and rotates agents before context exhaustion. Configure thresholds in `config.toml` if defaults (80% warning, 95% rotate) need adjustment.

8. **Safety blocks dangerous ops** — Force pushes, `rm -rf /`, and `DROP TABLE` are blocked by default. Custom policies go in `~/.ntm/policy.yaml`.

## Shell Integration

Enable shell aliases for faster access:

```bash
eval "$(ntm shell zsh)"   # or bash/fish
```

Key aliases: `cc`/`cod`/`gmi` (launch agents), `sat` (spawn), `dash`/`d` (dashboard), `bp` (send), `ncp` (palette), `knt` (kill), `lnt` (list), `snt` (status).
