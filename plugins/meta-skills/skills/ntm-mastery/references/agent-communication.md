# Agent Communication Reference

> **Compatibility**: ntm v1.x (March 2026)

## Direct Communication

### `ntm send <session>`

Broadcast prompts to agents within a session.

```bash
# Send to all Claude agents
ntm send myapi --cc "implement the /users REST endpoint"

# Send to all Codex agents
ntm send myapi --cod "write unit tests for the auth module"

# Send to all Gemini agents
ntm send myapi --gmi "review the API schema for inconsistencies"

# Send to ALL agents in the session
ntm send myapi --all "checkpoint: commit your current changes"

# Send to a specific pane by index
ntm send myapi --pane=2 "focus on error handling"
```

**Target flags:**
- `--cc` — All Claude agents
- `--cod` — All Codex agents
- `--gmi` — All Gemini agents
- `--all` — Every agent in the session
- `--pane=N` — Specific pane index

**Best practices:**
- Be specific in prompts — agents have no shared context unless explicitly coordinated
- Use `--all` for synchronization points ("commit", "report status")
- Use type-specific sends for role-based task assignment
- Follow up with `ntm activity` to verify agents are processing

### `ntm interrupt <session>`

Send Ctrl+C (SIGINT) to all agent panes.

```bash
ntm interrupt myapi
```

Use this as an emergency stop when agents are going off track, or to cancel long-running operations across all agents simultaneously.

## Agent Mail System

Agent Mail enables cross-session coordination. Unlike `send` (which works within a session), mail routes messages using the project working directory as a key — so agents in different sessions working on the same project can communicate.

### Sending Mail

```bash
# Send to a specific agent by name
ntm mail send myproject --to GreenCastle "Review the API changes in internal/handler.go"

# Broadcast to all agents across sessions
ntm mail send myproject --all "Checkpoint: sync and report status"
```

Agent names (like `GreenCastle`, `BlueLake`) are auto-assigned by ntm. Check names with `ntm status`.

### Reading Mail

```bash
# View all agent inboxes for the project
ntm mail inbox myproject

# Read a specific agent's mail
ntm mail read myproject --agent BlueLake
```

### Acknowledging Messages

```bash
# Acknowledge a specific message by ID
ntm mail ack myproject 42
```

Acknowledgment prevents the same message from showing as unread. Agents should ack messages after processing them.

### File Reservations

File reservations prevent conflicting edits when multiple agents work on the same codebase.

```bash
# Reserve files for an agent
ntm mail reserve myproject --agent BlueLake --paths "internal/api/*.go"

# Reserve multiple paths
ntm mail reserve myproject --agent GreenCastle --paths "cmd/server/*.go,configs/*.yaml"
```

**How reservations work:**
- An agent reserves file paths (glob patterns supported)
- Other agents see the reservation and should avoid those files
- The pre-commit guard blocks commits that conflict with reservations

### Pre-Commit Guard

Install the guard to enforce file reservations at commit time:

```bash
# Install the pre-commit hook
ntm hooks guard install

# Uninstall when no longer needed
ntm hooks guard uninstall
```

The guard checks staged files against active reservations and blocks the commit if conflicts exist.

## Communication Patterns

### Role-Based Task Distribution

Assign different roles to different agent types:

```bash
ntm spawn myapi --cc=2 --cod=1 --gmi=1
ntm send myapi --cc "implement the feature: user profile endpoint"
ntm send myapi --cod "write comprehensive tests for user profiles"
ntm send myapi --gmi "review the architecture and suggest improvements"
```

### Synchronized Checkpoints

Periodically align all agents:

```bash
ntm send myapi --all "Stop and commit current work. Then report what you've done."
ntm copy myapi --all --output /tmp/progress.txt
```

### Cross-Session Coordination

When features span multiple sessions:

```bash
# Session A works on backend
ntm mail send myapi --to BackendAgent "API contract is finalized, see openapi.yaml"

# Session B works on frontend
ntm mail send myapi --to FrontendAgent "Backend API is ready, start integration"
```

### Human Overseer Mode

Send high-priority instructions that override agent tasks:

```bash
ntm mail send myproject --all "[PRIORITY] Stop current work. Critical bug in auth module needs immediate fix."
```
