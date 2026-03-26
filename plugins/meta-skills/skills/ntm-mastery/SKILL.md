---
name: ntm-mastery
description: >
  Expert guidance for ntm (Named Tmux Manager) — the CLI that turns tmux into a
  multi-agent control plane for Claude, Codex, and Gemini. Covers session orchestration,
  prompt dispatch, work triage, file coordination, safety policies, pipelines, and
  monitoring. Use this skill whenever the user wants to coordinate multiple AI coding
  agents in parallel, whether they mention ntm explicitly or not. Also trigger when
  you see ntm commands (spawn, send, dashboard, work, assign, pipeline, serve, mail,
  locks, checkpoint, approve, safety, policy), multi-agent tmux patterns, or when the
  user is struggling with manual multi-agent coordination and could benefit from ntm.
  Proactively suggest ntm when the user runs 2+ agents on the same codebase without
  coordination tooling.
version: 0.3.0
---

# NTM Mastery — Named Tmux Manager

> **Compatibility**: Verified against ntm v1.x (March 2026)
> GitHub: https://github.com/Dicklesworthstone/ntm

NTM transforms tmux into a local control plane for multi-agent software development. It combines session orchestration, graph-aware work triage, safety policies, Agent Mail coordination, durable state capture, and automation surfaces (robot JSON, REST/WebSocket API) in one Go binary.

## Quick Start

```bash
ntm spawn myproject --cc=2 --cod=1     # Launch 2 Claude + 1 Codex agent
ntm send myproject --cc "implement auth" # Send task to Claude agents
ntm dashboard myproject                  # Open live monitoring TUI
ntm kill -f myproject                    # Terminate session
```

## When to Use What

Use this table to pick the right command for the situation. Load the linked reference for details.

### Session Lifecycle → `session-management.md`

| Situation | Command |
|-----------|---------|
| Start a project with scaffold | `ntm quick <project> --template=go\|python\|node\|rust` |
| Launch agents immediately | `ntm spawn <session> --cc=N --cod=N --gmi=N` |
| Multiple swarms on same project | `ntm spawn <session> --label backend` / `--label frontend` |
| Initialize config without agents | `ntm init <project>` |
| Add agents to running session | `ntm add <session> --cc=N` |
| Inspect layout without attaching | `ntm view <session>` / `ntm zoom <session> <pane>` |
| Terminate | `ntm kill -f <session>` |

### Dispatch & Coordination → `agent-communication.md`

| Situation | Command |
|-----------|---------|
| Send prompt to agent type | `ntm send <s> --cc\|cod\|gmi "prompt"` |
| Send to all agents | `ntm send <s> --all "checkpoint and report"` |
| Cross-session messaging | `ntm mail send <project> --to <agent> "message"` |
| Reserve files to prevent conflicts | `ntm mail reserve <project> --agent X --paths "src/**"` |
| Inspect/manage file locks | `ntm locks list\|renew\|force-release` |
| Emergency stop | `ntm interrupt <session>` |

### Monitoring & Analysis → `monitoring.md`

| Situation | Command |
|-----------|---------|
| Visual dashboard with health badges | `ntm dashboard <session>` |
| Quick status check | `ntm status <session>` |
| Agent health assessment | `ntm health <session>` |
| Live output streaming | `ntm watch <session>` |
| Compare two agent responses | `ntm diff <session> cc_1 cod_1` |
| Extract code from agent output | `ntm extract <session> --lang=go` |
| Search pane history | `ntm grep "pattern" <session> -C 3` |
| Usage analytics | `ntm analytics --days 7` |
| Export output to file | `ntm copy <session> --all --output FILE` |

### Work Intelligence → `work-intelligence.md`

| Situation | Command |
|-----------|---------|
| Triage what to work on next | `ntm work triage [--by-track]` |
| Get single highest-priority task | `ntm work next` |
| Auto-assign tasks to agents | `ntm assign <session> --auto --strategy=dependency` |
| Check for blockers | `ntm work alerts` |
| Human overseer digest | `ntm coordinator digest <session>` |

> Requires `br`/`bv` integration for graph-aware features. Without it, use manual bead creation + `ntm assign`.

### Automation & Pipelines → `pipelines-automation.md`

| Situation | Command |
|-----------|---------|
| Run multi-step workflow | `ntm pipeline run .ntm/pipelines/review.yaml --session <s>` |
| Reusable session presets | `ntm recipes list\|show` |
| Orchestration patterns | `ntm workflows list\|show` |
| Prompt templates | `ntm template list\|show` |
| Local REST/SSE/WebSocket server | `ntm serve --port 7337` |
| Generate OpenAPI spec | `ntm openapi generate` |

### Safety & Approvals → `hooks-safety.md`

| Situation | Command |
|-----------|---------|
| Check safety status | `ntm safety status` |
| Pre-check a command | `ntm safety check -- <command>` |
| Manage policy rules | `ntm policy show\|validate\|edit\|reset` |
| Review pending approvals | `ntm approve list\|show\|<id>\|deny` |
| Install pre-commit guard | `ntm hooks guard install` |

### Durable State & Recovery → `advanced-patterns.md`

| Situation | Command |
|-----------|---------|
| Save checkpoint before risky work | `ntm checkpoint save <s> -m "description"` |
| Resume interrupted session | `ntm resume <session>` |
| View event timeline | `ntm timeline list\|show <id>` |
| Audit trail | `ntm audit show <session>` |
| Search past sessions | `ntm history search "keyword"` |
| Check context usage per agent | `ntm --robot-context=<session>` |

### Programmatic Integration → `robot-mode.md`

| Situation | Command |
|-----------|---------|
| Machine-readable status | `ntm --robot-status --json` |
| Full state snapshot | `ntm --robot-snapshot` |
| Send prompt programmatically | `ntm --robot-send=<s> --msg="task" --type=claude` |
| Minimal LLM-friendly state | `ntm --robot-terse` |

## Common Tasks

**"I want to split work between Claude and Codex"**
```bash
ntm spawn myapi --cc=2 --cod=1
ntm send myapi --cc "implement the REST endpoints"
ntm send myapi --cod "write unit tests for the endpoints"
ntm mail reserve myapi --agent cc_1 --paths "internal/api/**"
ntm dashboard myapi
```

**"I need a CI pipeline that runs agent-powered code review"**
```bash
ntm --robot-spawn=ci-review --spawn-cc=2
ntm --robot-send=ci-review --msg="Review changed files. Report as JSON." --type=claude
ntm --robot-ack=ci-review --ack-timeout=300s
ntm --robot-files=ci-review --json
ntm kill -f ci-review
```

**"An agent is stuck, how do I recover?"**
```bash
ntm health myproject                           # Check health states
ntm --robot-tail=myproject --panes=2 --lines=50 # Inspect stuck pane
ntm --robot-context=myproject                   # Check context usage
ntm interrupt myproject                         # Ctrl+C all agents
ntm send myproject --cc "continue with the task" # Re-prompt
```

**"I want multiple teams on the same repo without conflicts"**
```bash
ntm spawn payments --label backend --cc=2 --cod=1
ntm spawn payments --label frontend --cc=2 --gmi=1
ntm mail reserve payments --agent BackendLead --paths "internal/**/*.go"
ntm mail reserve payments --agent FrontendLead --paths "web/src/**/*.tsx"
ntm hooks guard install  # Block conflicting commits
```

## Selective Reference Loading

Load the relevant reference only when the task requires deeper knowledge. Each section header above notes which reference to load.

```
# Session lifecycle (spawn, create, quick, init, attach, view, zoom, kill, list, labels):
Read: $SKILL_PATH/references/session-management.md

# Sending prompts, mail system, file reservations, locks, worktrees:
Read: $SKILL_PATH/references/agent-communication.md

# Dashboard, status, health, activity, extract, diff, grep, analytics, state detection:
Read: $SKILL_PATH/references/monitoring.md

# Work triage (br/bv), assignment strategies, coordinator (human overseer):
Read: $SKILL_PATH/references/work-intelligence.md

# Pipelines, recipes, workflows, templates, REST/SSE/WebSocket API, OpenAPI:
Read: $SKILL_PATH/references/pipelines-automation.md

# Robot mode JSON API (--robot-* flags):
Read: $SKILL_PATH/references/robot-mode.md

# config.toml, environment variables, palette, project-level .ntm/:
Read: $SKILL_PATH/references/configuration.md

# Hook system, safety policies, approvals, guards, pre-commit guard:
Read: $SKILL_PATH/references/hooks-safety.md

# Context rotation, conflicts, beads, CASS, ensembles, profiles, checkpoints, timelines, audit:
Read: $SKILL_PATH/references/advanced-patterns.md

# End-to-end workflow templates (solo dev, team coordination, code review, migration, CI/CD):
Read: $SKILL_PATH/references/workflows.md

# Error diagnosis and recovery:
Read: $SKILL_PATH/references/troubleshooting.md
```

## Essential Rules

1. **Pane naming** — `<project>__<type>_<number>` (e.g., `myapi__cc_1`). Shorthands: `cc` = Claude, `cod` = Codex, `gmi` = Gemini.

2. **Session = project directory** — `ntm spawn myapi` creates agents working in `~/Developer/myapi/` (configurable via `projects_base`).

3. **Labels for multi-swarm** — `--label` runs multiple swarms on the same project. Without labels, re-spawning replaces the session.

4. **Robot mode vs REST** — `--robot-*` flags for local scripting/CI. `ntm serve` for long-lived dashboards and external services.

5. **Mail within, locks across** — `ntm send` within a session. `ntm mail` across sessions. `ntm locks` to manage file reservations.

6. **Safety is on by default** — Force pushes, `rm -rf /`, `DROP TABLE` blocked. `approval`-gated operations require `ntm approve`. Custom policies in `~/.ntm/policy.yaml`.

7. **Context rotation is automatic** — 80% warning, 95% rotate. Attempts compaction first. Configure in `config.toml` → `[context_rotation]`.

8. **Project-level `.ntm/` overrides user config** — Use for team-shared recipes, pipelines, personas, and checkpoints.

9. **Durable state by default** — Checkpoints, timelines, and audit trails persist. Always `ntm checkpoint save` before risky operations.

## Shell Integration

```bash
eval "$(ntm shell zsh)"   # or bash/fish
```

Key aliases: `cc`/`cod`/`gmi` (launch agents), `sat` (spawn), `dash`/`d` (dashboard), `bp` (send), `ncp` (palette), `knt` (kill), `lnt` (list), `snt` (status).
