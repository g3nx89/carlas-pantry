# Work Intelligence Reference

> **Compatibility**: ntm v1.x (March 2026)

NTM integrates with `br` (Bead Runner) and `bv` (Bead Viewer) for graph-aware work triage. This enables intelligent task selection, impact analysis, and assignment — moving beyond "send prompts and hope" to structured work management.

**Prerequisite**: Work commands require a repo with Beads/BV data. Outside the project root, commands have nothing to analyze. Check with `ntm deps -v`.

## Work Triage

### `ntm work triage`

Surface the best next tasks based on dependency graph, blockers, and priorities.

```bash
# Default triage view
ntm work triage

# Group by track
ntm work triage --by-track

# Machine-readable output
ntm work triage --format=markdown
```

### `ntm work next`

Get the single highest-priority next task.

```bash
ntm work next
```

### `ntm work alerts`

View active work alerts (blockers, stale tasks, dependency violations).

```bash
ntm work alerts
```

### `ntm work search`

Search the work graph by keyword.

```bash
ntm work search "JWT auth"
ntm work search "migration"
```

### `ntm work impact`

Analyze the impact of changes to a specific file on the work graph.

```bash
ntm work impact internal/api/auth.go
```

### `ntm work graph`

Visualize the dependency graph.

```bash
ntm work graph
```

---

## Assignment

### `ntm assign <session>`

Assign beads (work items) to specific agents or let ntm auto-assign.

```bash
# Auto-assign with dependency-aware strategy
ntm assign payments --auto --strategy=dependency

# Assign specific beads to a specific agent type
ntm assign payments --beads=br-123,br-124 --agent=codex

# Assign with quality-first strategy
ntm assign payments --auto --strategy=quality
```

**Flags:**
- `--auto` — Auto-assign without confirmation
- `--strategy=balanced|speed|quality|dependency` — Assignment algorithm
- `--beads=id1,id2` — Specific bead IDs to assign
- `--agent=claude|codex|gemini` — Target agent type

**Assignment strategies:**

| Strategy | Behavior |
|----------|----------|
| `balanced` | Even distribution, respects agent strengths |
| `speed` | Maximize throughput — any idle agent to any ready task |
| `quality` | Strict capability-to-task matching |
| `dependency` | Prioritize unblocking high-impact work |

Also available via robot mode: `ntm --robot-assign=SESSION` (see `robot-mode.md`).

---

## Coordinator (Human Overseer)

The coordinator surface lets the human operator inspect coordination state across agents without dropping into raw tmux or mail.

### `ntm coordinator status <session>`

Overview of agent assignments, active tasks, and coordination health.

```bash
ntm coordinator status payments
```

### `ntm coordinator digest <session>`

Summarized digest of recent agent activity, decisions, and progress.

```bash
ntm coordinator digest payments
```

### `ntm coordinator conflicts <session>`

View active and recent file conflicts between agents.

```bash
ntm coordinator conflicts payments
```

---

## Workflow Integration

Work intelligence pairs naturally with other ntm features:

```bash
# 1. Triage what needs doing
ntm work triage --by-track

# 2. Auto-assign to agents
ntm assign payments --auto --strategy=dependency

# 3. Reserve files to prevent conflicts
ntm mail reserve payments --agent AuthAgent --paths "internal/auth/**"

# 4. Monitor progress
ntm dashboard payments

# 5. Check for blockers
ntm work alerts
```
