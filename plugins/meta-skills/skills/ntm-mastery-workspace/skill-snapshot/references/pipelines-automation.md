# Pipelines & Automation Reference

> **Compatibility**: ntm v1.x (March 2026)

NTM supports several layers of reusable automation — from simple session presets (recipes) to executable multi-step agent workflows (pipelines) to a full local REST/WebSocket API for external integrations.

## Pipelines

Executable multi-step agent workflows with variables, dependencies, resume capability, and cleanup.

### Commands

```bash
# Run a pipeline
ntm pipeline run .ntm/pipelines/review.yaml --session payments

# Check pipeline status
ntm pipeline status run-20241230-123456-abcd

# List all pipeline runs
ntm pipeline list

# Resume a failed/interrupted pipeline
ntm pipeline resume run-20241230-123456-abcd

# Clean up old pipeline artifacts
ntm pipeline cleanup --older=7d
```

Pipeline definitions live in `.ntm/pipelines/` (project-level) or `~/.config/ntm/pipelines/` (user-level).

---

## Recipes

Reusable session presets — predefined agent mixes and configurations.

```bash
# List available recipes
ntm recipes list

# Show recipe details
ntm recipes show full-stack
```

Recipes are defined in `.ntm/recipes.toml` (project) or `~/.config/ntm/recipes.toml` (user).

---

## Workflows

Orchestration patterns such as pipeline, ping-pong, and review-gate.

```bash
# List available workflow patterns
ntm workflows list

# Show workflow details
ntm workflows show red-green
```

Workflow definitions live in `.ntm/workflows/` (project) or `~/.config/ntm/workflows/` (user).

---

## Prompt Templates

Reusable prompt templates with variable substitution.

```bash
# List available templates
ntm template list

# Show template content
ntm template show fix-bug
```

Templates support dynamic fields:
```toml
prompt = "Implement {{.Feature}} with {{.Style}} coding style"
```

---

## Session Templates

Higher-level session layouts — predefined combinations of agent types, profiles, and workflow configurations.

```bash
ntm session-templates list
ntm session-templates show review-panel
```

---

## REST, SSE, WebSocket API

NTM exposes a local server for dashboards, scripts, and external integrations.

### Starting the Server

```bash
ntm serve
ntm serve --port 7337
```

### API Surfaces

| Surface | Endpoint | Purpose |
|---------|----------|---------|
| REST API | `/api/v1/*` | Full CRUD operations on sessions, agents, mail, beads |
| Server-Sent Events | `/events` | Real-time event stream (agent state changes, alerts, mail) |
| WebSocket | `/ws` | Bidirectional subscriptions for live dashboards |
| Health Check | `/health` | Server and session health status |

### OpenAPI Specification

Generate or refresh the OpenAPI document describing all REST endpoints:

```bash
# Generate to default location (docs/openapi.json)
ntm openapi generate

# Output to stdout
ntm openapi generate --stdout
```

The generated spec is at `docs/openapi.json` in the ntm repository.

### When to Use REST vs Robot Mode

| Scenario | Preferred Surface |
|----------|-------------------|
| Local scripting, single CLI calls | Robot mode (`--robot-*` flags) |
| Agent-to-agent coordination within Claude Code | Robot mode |
| Long-lived dashboards, web UIs | `ntm serve` REST/WebSocket |
| CI/CD pipelines | Robot mode (simpler, no server dependency) |
| External service integration | `ntm serve` REST API |
| Real-time monitoring feeds | `ntm serve` SSE/WebSocket |

---

## Durable State & Recovery

NTM treats recoverability as a core feature. These commands provide forensic surfaces and session recovery.

### Timeline

Replay-capable session timelines with event sequencing.

```bash
# List all timelines
ntm timeline list

# Show timeline for a specific session
ntm timeline show <session-id>
```

### Audit

Exportable audit records of agent actions and operator decisions.

```bash
# Show audit trail for a session
ntm audit show payments
```

### History Search

Search across past prompt and session history.

```bash
ntm history search "authentication error"
```

### Change Tracking

Track and review file changes across agents.

```bash
# View conflicts between agent changes
ntm changes conflicts payments
```

### Session Resume

Resume a previously checkpointed or interrupted session.

```bash
ntm resume payments
```

Pairs with checkpoints (see `advanced-patterns.md`):
```bash
ntm checkpoint save payments -m "before risky change"
# ... something goes wrong ...
ntm resume payments
```
