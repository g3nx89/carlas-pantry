# Troubleshooting Reference

> **Compatibility**: ntm v1.x (March 2026)

## Dependency Issues

### Problem: `ntm deps -v` shows missing tools

**Symptoms:** ntm reports missing tmux, claude, codex, or gemini.

**Resolution:**
```bash
# Check what's missing
ntm deps -v

# Install tmux
brew install tmux          # macOS
apt install tmux           # Ubuntu/Debian

# Verify agent CLIs are in PATH
which claude codex gemini
```

### Problem: ntm command not found

**Resolution:**
```bash
# Check installation
which ntm

# Reinstall
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/ntm/main/install.sh?$(date +%s)" | bash -s -- --easy-mode

# Or via Homebrew
brew install dicklesworthstone/tap/ntm
```

---

## Session Issues

### Problem: Session won't spawn

**Symptoms:** `ntm spawn` fails or hangs.

**Possible causes:**
1. **tmux server not running** — ntm starts it automatically, but check: `tmux ls`
2. **Session name conflict** — A session with that name already exists: `ntm list`
3. **Agent CLI not installed** — Verify with `ntm deps -v`
4. **projects_base doesn't exist** — Create: `mkdir -p ~/Developer`

**Resolution:**
```bash
# Kill stale tmux server
tmux kill-server

# Check for existing sessions
ntm list

# Retry with verbose output
NTM_PROFILE=1 ntm spawn myapi --cc=1
```

### Problem: Can't attach to session

**Symptoms:** `ntm attach` fails with "session not found".

**Resolution:**
```bash
# List actual tmux sessions (bypass ntm)
tmux list-sessions

# Session may have been killed — recreate
ntm spawn myapi --cc=2
```

### Problem: Panes not tiling correctly

**Symptoms:** Pane layout is broken or overlapping.

**Resolution:**
- Resize terminal window to at least 120 columns wide
- Detach and reattach: `ntm attach <session>`
- Within tmux: `Ctrl-B`, then `Space` to cycle layouts

---

## Agent State Issues

### Problem: Agent stuck in STALLED state

**Symptoms:** Dashboard shows STALLED for an agent that should be active.

**Possible causes:**
1. **Agent crashed silently** — Check pane output: `ntm --robot-tail=SESSION --panes=N --lines=50`
2. **Rate limited** — API provider may be throttling: `ntm health SESSION`
3. **Context exhausted** — Agent hit token limit: `ntm --robot-context=SESSION`
4. **Stall threshold too low** — Increase in config: `detection.stall_threshold_sec`

**Resolution:**
```bash
# Check agent output
ntm --robot-tail=myapi --panes=2 --lines=50

# If crashed, interrupt and resend
ntm interrupt myapi
ntm send myapi --cc "continue with the task"

# If context exhausted, check rotation
ntm --robot-context=myapi
```

### Problem: State detection shows wrong state

**Symptoms:** Agent appears WAITING when it's actually working, or vice versa.

**Cause:** Detection patterns don't match agent's actual output format.

**Resolution:** Customize detection patterns in `config.toml`:
```toml
[detection.patterns.claude]
idle = ["claude>", "Claude >", "❯", "your-custom-prompt>"]
error = ["Error:", "rate_limit", "your-custom-error"]
```

---

## Context Rotation Issues

### Problem: Context rotation not triggering

**Symptoms:** Agent hits context limit and crashes instead of rotating.

**Resolution:**
```bash
# Verify rotation is enabled
grep "context_rotation" ~/.config/ntm/config.toml

# Check thresholds
ntm --robot-context=myapi
```

Ensure `config.toml` has:
```toml
[context_rotation]
enabled = true
warning_threshold = 0.80
rotate_threshold = 0.95
```

### Problem: Recovery prompt spam

**Symptoms:** After compaction, the recovery prompt fires repeatedly.

**Resolution:** Increase cooldown and reduce max recoveries:
```toml
[context_rotation.recovery]
cooldown_seconds = 60          # Increase from default 30
max_recoveries_per_pane = 3    # Decrease from default 5
```

### Problem: Handoff summary too brief / too long

**Resolution:** Adjust `summary_max_tokens`:
```toml
[context_rotation]
summary_max_tokens = 3000      # Increase for more detail
```

---

## Communication Issues

### Problem: `ntm send` delivers to wrong agents

**Symptoms:** Messages go to unintended panes.

**Resolution:**
```bash
# Check pane naming to understand the mapping
ntm status myapi

# Use explicit pane targeting
ntm send myapi --pane=2 "your prompt"
```

### Problem: Agent Mail messages not routing

**Symptoms:** `ntm mail inbox` shows no messages despite sending.

**Cause:** `projects_base` misalignment. Mail routes by project directory — if sessions use different base paths, mail won't route.

**Resolution:**
```bash
# Verify both sessions point to same project
ntm status session-a
ntm status session-b

# Check projects_base in config
grep projects_base ~/.config/ntm/config.toml
```

---

## Performance Issues

### Problem: Dashboard is slow or laggy

**Resolution:**
```bash
# Disable animations
export NTM_REDUCE_MOTION=1

# Use simpler icons
export NTM_ICONS=ascii

# Increase poll interval in config
# [detection]
# poll_interval_ms = 1000  # Default 500
```

### Problem: Startup is slow

**Resolution:**
```bash
# Profile startup
NTM_PROFILE=1 ntm spawn myapi --cc=1

# Check if shell aliases are loading slowly
time eval "$(ntm shell zsh)"
```

---

## Safety & Hook Issues

### Problem: Safety blocking legitimate commands

**Resolution:**
```bash
# Check what's blocked
ntm safety blocked

# Pre-check specific command
ntm safety check "git push --force-with-lease"

# Add explicit allow rule in ~/.ntm/policy.yaml
# rules:
#   - pattern: "git push --force-with-lease"
#     action: allow
#     reason: "Force-with-lease is safe"
```

### Problem: Hook failing and blocking commands

**Resolution:**
```bash
# Check which hook is failing
# Look at the error message — it includes the hook name

# Temporarily disable the hook
# In ~/.config/ntm/hooks.toml:
# enabled = false

# Or set continue_on_error for non-critical hooks
# continue_on_error = true
```

### Problem: Pre-commit guard blocking valid commits

**Symptoms:** `git commit` fails due to file reservation conflict.

**Resolution:**
```bash
# Check active reservations
ntm mail inbox myproject

# Release the reservation
ntm mail ack myproject <reservation-id>

# Or temporarily uninstall the guard
ntm hooks guard uninstall
```

---

## Rate Limiting

### Problem: Agents hitting API rate limits

**Symptoms:** Dashboard shows RATE_LIMITED state, agents producing error output.

**Resolution:**
1. Reduce agent count — fewer parallel agents = fewer API calls
2. Stagger sends — don't send to all agents simultaneously
3. Check provider quotas and upgrade if needed
4. Enable alerting to catch rate limits early:

```toml
[alerting]
alert_on = ["rate_limited"]
```

---

## Nuclear Options

When nothing else works:

```bash
# Kill everything and start fresh
ntm kill -f <session>
tmux kill-server

# Reset ntm config to defaults
ntm policy reset

# Full reinstall
ntm upgrade
```

**Warning:** `tmux kill-server` terminates ALL tmux sessions, not just ntm-managed ones. Use only when necessary.
