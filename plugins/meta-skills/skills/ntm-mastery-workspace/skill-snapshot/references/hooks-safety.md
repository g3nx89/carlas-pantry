# Hooks & Safety Reference

> **Compatibility**: ntm v1.x (March 2026)

## Hook System

Hooks provide pre- and post-command automation defined in `~/.config/ntm/hooks.toml`.

### Available Events

| Event | When It Fires |
|-------|--------------|
| `pre-spawn` | Before session spawn |
| `post-spawn` | After session spawn |
| `pre-send` | Before prompt delivery |
| `post-send` | After prompt delivery |
| `pre-add` | Before adding agents |
| `post-add` | After adding agents |
| `pre-create` | Before session creation |
| `post-create` | After session creation |
| `pre-shutdown` | Before session kill |
| `post-shutdown` | After session kill |

### Hook Configuration

```toml
[[command_hooks]]
event = "post-send"
command = "./my-script.sh"
name = "my-hook"
timeout = "30s"
enabled = true
continue_on_error = false
workdir = "${PROJECT}"

[command_hooks.env]
MY_VAR = "custom_value"
```

**Fields:**
- `event` — Which event triggers this hook
- `command` — Shell command to execute (via `sh -c`)
- `name` — Human-readable identifier
- `timeout` — Max execution time (default 30s, max 10 min)
- `enabled` — Toggle without removing
- `continue_on_error` — If false, pre-hooks abort the command on failure
- `workdir` — Working directory (defaults to project directory)
- `env` — Additional environment variables

### Hook Behavior

- **Pre-hooks** abort the parent command on failure (unless `continue_on_error = true`)
- **Post-hooks** log failures but don't fail the overall command
- Default timeout: 30 seconds; maximum: 10 minutes
- Execution via shell: `sh -c "command"`
- Working directory defaults to project directory

### Environment Variables

**Available in all hooks:**

| Variable | Description |
|----------|-------------|
| `NTM_SESSION` | Session name |
| `NTM_PROJECT_DIR` | Project directory path |
| `NTM_HOOK_EVENT` | Event name that triggered |
| `NTM_HOOK_NAME` | Hook's `name` field |

**Send event-specific variables:**

| Variable | Description |
|----------|-------------|
| `NTM_MESSAGE` | The prompt text being sent |
| `NTM_SEND_TARGETS` | Target specification |
| `NTM_TARGET_CC` | "true" if Claude agents targeted |
| `NTM_TARGET_COD` | "true" if Codex agents targeted |
| `NTM_TARGET_GMI` | "true" if Gemini agents targeted |
| `NTM_TARGET_ALL` | "true" if all agents targeted |
| `NTM_PANE_INDEX` | Specific pane index (if targeted) |
| `NTM_DELIVERED_COUNT` | (post-send) How many panes received the message |
| `NTM_FAILED_COUNT` | (post-send) How many deliveries failed |
| `NTM_TARGET_PANES` | (post-send) Comma-separated pane IDs |

**Spawn event-specific variables:**

| Variable | Description |
|----------|-------------|
| `NTM_AGENT_COUNT_CC` | Number of Claude agents spawned |
| `NTM_AGENT_COUNT_COD` | Number of Codex agents spawned |
| `NTM_AGENT_COUNT_GMI` | Number of Gemini agents spawned |
| `NTM_AGENT_COUNT_TOTAL` | Total agents spawned |

### Hook Examples

**Slack notification on spawn:**
```toml
[[command_hooks]]
event = "post-spawn"
name = "slack-notify-spawn"
command = 'curl -X POST -H "Content-Type: application/json" -d "{\"text\":\"NTM session ${NTM_SESSION} spawned with ${NTM_AGENT_COUNT_TOTAL} agents\"}" https://hooks.slack.com/...'
timeout = "10s"
```

**Git status check before send:**
```toml
[[command_hooks]]
event = "pre-send"
name = "git-dirty-check"
command = 'cd ${NTM_PROJECT_DIR} && git diff --quiet || echo "WARNING: Uncommitted changes"'
continue_on_error = true
```

**Log all prompts:**
```toml
[[command_hooks]]
event = "post-send"
name = "prompt-logger"
command = 'echo "${NTM_MESSAGE}" >> ${NTM_PROJECT_DIR}/.ntm-prompts.log'
```

---

## Safety System

ntm recognizes dangerous patterns and blocks or requires approval.

### Protected Patterns (Defaults)

| Pattern | Action | Reason |
|---------|--------|--------|
| `git reset --hard` | Block | Loses uncommitted changes |
| `git push --force` | Block | Overwrites remote history |
| `rm -rf /` | Block | Catastrophic deletion |
| `git clean -fd` | Approval | Deletes untracked files |
| `DROP TABLE` | Block | Database destruction |

### Safety Commands

```bash
# Check current safety status
ntm safety status

# View blocked commands (recent)
ntm safety blocked

# View blocked commands from last 24 hours
ntm safety blocked --hours=24

# Pre-check a command
ntm safety check "git reset --hard HEAD~1"

# Install safety hooks
ntm safety install
ntm safety install --force

# Uninstall safety hooks
ntm safety uninstall
```

### Custom Policies

Define custom safety rules in `~/.ntm/policy.yaml`:

```yaml
rules:
  - pattern: "rm -rf ${HOME}"
    action: block
    reason: "Prevents accidental home directory deletion"

  - pattern: "git push.*--force"
    action: approval
    reason: "Force push requires explicit confirmation"

  - pattern: "npm publish"
    action: approval
    reason: "Publishing requires explicit confirmation"

  - pattern: "docker system prune"
    action: warn
    reason: "May remove needed images"
```

**Available actions:**
- `block` — Immediately reject the command
- `approval` — Require user confirmation before proceeding
- `warn` — Log warning but allow execution
- `allow` — Explicitly permit (override default blocks)

### Policy Management

```bash
# Show active policy rules
ntm policy show

# Show all rules including defaults
ntm policy show --all

# Validate policy syntax
ntm policy validate

# Reset to default policy
ntm policy reset

# Edit policy in $EDITOR
ntm policy edit
```

### Pre-Commit Guard

The pre-commit guard enforces Agent Mail file reservations at commit time:

```bash
# Install the guard hook
ntm hooks guard install

# Uninstall the guard hook
ntm hooks guard uninstall
```

When installed, `git commit` checks staged files against active file reservations and blocks commits that would conflict with another agent's reserved paths.

---

## Approval Workflows

For operations classified as `approval` in policy, ntm provides a durable, auditable approval system. Approvals support two-person workflows for high-risk operations.

### Commands

```bash
# List pending approvals
ntm approve list

# Show details of a specific approval request
ntm approve show abc123

# Approve a pending request
ntm approve abc123

# Deny with reason
ntm approve deny abc123 --reason "wrong target branch"
```

### How Approvals Work

1. An agent or command triggers an operation matching an `approval` policy rule
2. NTM blocks the operation and creates an approval request with a unique ID
3. The human operator reviews via `ntm approve list` / `ntm approve show`
4. Operator approves or denies — the decision is recorded in the audit trail
5. If approved, the original operation proceeds; if denied, it's permanently blocked

### Approval Properties

- **Durable** — Approvals persist across ntm restarts
- **Auditable** — Every approval/denial is logged with timestamp, operator, and reason
- **Two-person capable** — Different operator can review vs. the one who triggered

---

## Guards

Guards provide runtime protection beyond static policy rules — active monitoring and blocking of dangerous patterns during agent execution.

### Commands

```bash
# View guard status
ntm guards status

# List active guards
ntm guards list
```

Guards complement policy rules: policy defines WHAT is blocked, guards enforce it in real-time during agent execution.

### Policy Automation

Generate or manage policy rules programmatically:

```bash
ntm policy automation
```

Useful for CI/CD environments where policy needs to be version-controlled and applied automatically.
