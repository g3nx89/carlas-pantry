# Hooks Catalog

Available hooks for Claude Code harness configuration. Each hook includes its trigger,
purpose, and `.claude/settings.json` configuration.

## Hook Types

Claude Code supports these hook events:

| Event | Fires When | Common Use |
|-------|-----------|------------|
| `PostToolUse` | After a tool completes | Build verification, lint checks |
| `PreToolUse` | Before a tool executes | Blocking dangerous operations |
| `PreCommit` | Before git commit | Test gates, coverage checks |
| `PostCommit` | After git commit | Notifications, CI triggers |
| `UserPromptSubmit` | When user sends a message | Context injection, reminders |

## Essential Hooks

### Build Verification (PostToolUse)

Runs after code changes to catch build errors immediately. Fast feedback prevents the agent
from building on broken foundations.

```json
{
  "matcher": "Edit|Write",
  "command": ".claude/scripts/verify-build.sh",
  "description": "Verify build after code changes"
}
```

Script should: run the build command, print clear error + file:line on failure, exit 0 on success.

**When to use:** Almost always. Skip only for non-compiled languages with no build step.

### Test Gate (PreCommit)

Prevents commits when tests fail. The most important enforcement hook — a commit with
failing tests poisons every subsequent session.

```json
{
  "command": ".claude/scripts/verify-tests.sh",
  "description": "Run tests before committing"
}
```

Script should: run the test suite, report which tests failed with file paths, exit non-zero
to block the commit.

**When to use:** Always, regardless of quality bar.

### Spec Protection (PreToolUse)

Blocks modification of planning artifacts. These files are the source of truth — accidental
edits silently corrupt the contract.

```json
{
  "matcher": "Edit|Write",
  "command": ".claude/scripts/protect-specs.sh \"$FILE_PATH\"",
  "description": "Protect planning artifacts from modification"
}
```

**When to use:** Balanced and thorough quality bars. Can skip for fast iteration if the user
is comfortable with the risk.

## Optional Hooks

### Coverage Check (PreCommit)

Block commits when test coverage drops below a threshold. Useful for thorough quality bar.

```json
{
  "command": ".claude/scripts/check-coverage.sh",
  "description": "Verify test coverage meets minimum threshold"
}
```

Script should: run coverage tool, compare against threshold, print uncovered files on failure.

**When to use:** Thorough quality bar only. Can be frustrating during fast iteration.

### Lint Check (PostToolUse)

Run linter after code changes. Catches style violations and common mistakes early.

```json
{
  "matcher": "Edit|Write",
  "command": ".claude/scripts/run-lint.sh \"$FILE_PATH\"",
  "description": "Lint changed files"
}
```

**When to use:** When the project has an established linter config. Don't add a linter
just for the harness — that's scope creep.

### Progress Reminder (UserPromptSubmit)

Injects a reminder about the current feature and progress state when the user sends a message.
Helps maintain focus across long sessions.

```json
{
  "command": "echo \"Current feature: $(jq -r '.features[] | select(.passes==false) | .id + \": \" + .description' .harness/feature-list.json | head -1)\"",
  "description": "Show current feature focus"
}
```

**When to use:** Optional quality-of-life hook. Most useful in long sessions with many features.

## Writing Custom Hooks

### The Remediation Pattern

Every hook script should follow this pattern on failure:

```
1. WHAT failed (clear error message)
2. WHERE it failed (file path, line number if available)
3. HOW to fix it (specific remediation steps)
```

This pattern is critical because the model reads hook output and uses it to self-correct.
A hook that only says "FAIL" wastes a retry. A hook that explains the fix resolves the
issue in one attempt.

### Script Template

```bash
#!/bin/bash
set -euo pipefail

# Run the check
OUTPUT=$({check_command} 2>&1) || {
  echo "FAILED: {what_failed}"
  echo ""
  echo "Details:"
  echo "$OUTPUT"
  echo ""
  echo "Remediation:"
  echo "  1. {step_1}"
  echo "  2. {step_2}"
  echo "  3. Run '{verify_command}' to confirm the fix"
  exit 1
}
```

### Performance Guidelines

- **Target: <5 seconds** — Hooks that take longer get perceived as broken
- **Scope narrowly** — Lint only the changed file, not the whole project
- **Cache when possible** — Incremental builds over full rebuilds
- **Use matchers** — Only trigger on relevant tool events (Edit|Write, not Read)

## Configuration Merging

When the project already has `.claude/settings.json`:

1. Read the existing file
2. Merge new hooks into the existing `hooks` object
3. Don't duplicate — check if a similar hook already exists (by description or command)
4. Preserve all non-hook settings
5. Write the merged result
