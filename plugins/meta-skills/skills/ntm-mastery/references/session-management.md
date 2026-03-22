# Session Management Reference

> **Compatibility**: ntm v1.x (March 2026)

## Session Lifecycle

Sessions are the top-level container. Each session maps to a tmux session with tiled panes — one user pane (index 0) plus N agent panes. Projects default to `~/Developer/<session-name>` (macOS) or `/data/projects/<session-name>` (Linux).

## Commands

### `ntm spawn <session>`

Launch a session with AI agents immediately.

```bash
# Launch 2 Claude + 1 Codex agent
ntm spawn myapi --cc=2 --cod=1

# Launch 3 Claude + 2 Codex + 1 Gemini
ntm spawn myapi --cc=3 --cod=2 --gmi=1

# With custom profiles
ntm spawn myapi --profiles=architect,implementer,tester
```

**Flags:**
- `--cc=N` — Number of Claude agents
- `--cod=N` — Number of Codex agents
- `--gmi=N` — Number of Gemini agents
- `--profiles=list` — Assign persona profiles to agents

**Behavior:**
- Creates tmux session named `<session>`
- Pane 0 is the user pane (shell prompt)
- Agent panes are tiled automatically based on terminal size
- Each agent starts in `projects_base/<session>/` directory
- Pane naming: `<session>__<type>_<number>` (e.g., `myapi__cc_1`)

### `ntm quick <project>`

Full project scaffold with agents — the fastest way to start.

```bash
# Go project with scaffold
ntm quick myapi --template=go

# Python project
ntm quick mlpipeline --template=python

# Node.js project
ntm quick webapp --template=node

# Rust project
ntm quick engine --template=rust
```

**Flags:**
- `--template=go|python|node|rust` — Language scaffold template

**Behavior:**
- Creates project directory with language-specific structure
- Initializes git repository
- Spawns a default agent mix
- Agents start with project context already loaded

### `ntm create <session>`

Create an empty session with generic panes (no AI agents).

```bash
# Create session with 4 empty panes
ntm create mywork --panes=4
```

**Flags:**
- `--panes=N` — Number of panes to create

Use this when setting up custom workflows where agents will be added later via `ntm add`.

### `ntm add <session>`

Add more agents to a running session.

```bash
# Add 2 more Claude agents
ntm add myapi --cc=2

# Add 1 Gemini agent
ntm add myapi --gmi=1
```

**Flags:**
- `--cc=N` — Claude agents to add
- `--cod=N` — Codex agents to add
- `--gmi=N` — Gemini agents to add

New panes are appended and the layout re-tiles automatically.

### `ntm attach <session>`

Reattach to an existing tmux session.

```bash
ntm attach myapi
```

Equivalent to `tmux attach-session -t <session>`, but with ntm's pane awareness.

### `ntm list`

Show all active tmux sessions managed by ntm.

```bash
ntm list
```

Displays session names, agent counts, and uptime.

### `ntm kill <session>`

Terminate a session and all its agent panes.

```bash
# Kill with confirmation prompt
ntm kill myapi

# Force kill without confirmation
ntm kill -f myapi
```

**Flags:**
- `-f` — Force kill without confirmation

**Warning:** This sends SIGTERM to all agents. Any unsaved work in agent context is lost. Use `ntm checkpoint save` before killing long-running sessions.

## Multi-Session Labels

Run multiple agent swarms on the same project with different goals:

```bash
# Session 1: feature development
ntm spawn myapi-features --cc=3

# Session 2: test writing (same project)
ntm spawn myapi-tests --cc=2 --cod=1
```

Both sessions can work in the same `~/Developer/myapi/` directory. Use Agent Mail for coordination between them and file reservations to prevent conflicts.

## Utility Commands

### `ntm deps -v`

Verify all required dependencies are installed (tmux, agents, etc.).

```bash
ntm deps -v
```

Run this before first use or when troubleshooting.

### `ntm bind`

Configure the F6 hotkey for opening the command palette from within tmux.

```bash
ntm bind
```

### `ntm tutorial`

Interactive onboarding walkthrough.

```bash
ntm tutorial
```

### `ntm upgrade`

Check for and apply self-updates.

```bash
ntm upgrade
```
