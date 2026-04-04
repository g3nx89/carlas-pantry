# Hooks Catalog

Available hooks for Claude Code harness configuration. Each hook includes its trigger,
purpose, and `.claude/settings.json` configuration.

## Hook Types

Claude Code supports these hook events:

| Event | Fires When | Common Use |
|-------|-----------|------------|
| `PreToolUse` | Before a tool executes | Blocking dangerous operations, commit gates |
| `PostToolUse` | After a tool completes | Build verification, lint checks, post-commit triggers |
| `UserPromptSubmit` | When user sends a message | Context injection, reminders |
| `Stop` | When the agent finishes a turn | Final verification, summary generation |
| `SessionStart` | When a new session begins | Context loading, environment checks |
| `Notification` | When the agent emits a notification | Alerts, logging |

Note: Claude Code does NOT have `PreCommit` or `PostCommit` events. To gate commits, use
`PreToolUse` with `matcher: "Bash"` — the script checks if the command is a git commit.
To react after commits, use `PostToolUse` with `matcher: "Bash"`.

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

### Test Gate (PreToolUse — Bash)

Prevents commits when tests fail. The most important enforcement hook — a commit with
failing tests poisons every subsequent session. Uses `PreToolUse` with a Bash matcher
because Claude Code has no dedicated commit event.

```json
{
  "matcher": "Bash",
  "command": ".claude/scripts/verify-tests-on-commit.sh",
  "description": "Run tests before committing"
}
```

Script receives JSON on stdin with `tool_input.command`. Parse with `jq`:
```bash
COMMAND=$(cat | jq -r '.tool_input.command // empty')
[[ "$COMMAND" == git\ commit* ]] || exit 0
```
If it is a commit, run the test suite, report which tests failed with file paths, exit
non-zero to block the commit.

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

### Coverage Check (PreToolUse — Bash)

Block commits when test coverage drops below a threshold. Useful for thorough quality bar.
Uses the same Bash matcher pattern as the test gate.

```json
{
  "matcher": "Bash",
  "command": ".claude/scripts/check-coverage-on-commit.sh",
  "description": "Verify test coverage meets minimum threshold"
}
```

Script receives JSON on stdin (same pattern as test gate). Parse command, exit 0 if not
a git commit. If it is a commit, run coverage tool, compare against threshold, print
uncovered files on failure.

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

## Architecture Guards

Structural tests that validate the plan's architectural boundaries. Unlike generic lint,
these are project-specific invariants extracted from `plan.md` and `ARCHITECTURE.md`
during Stage 2b. Inspired by OpenAI's "taste invariants" pattern: *"the constraints are
what allows speed without decay or architectural drift."*

### Import Boundary Guard (PostToolUse)

Verifies that module dependencies follow the layered architecture.

```json
{
  "matcher": "Edit|Write",
  "command": ".claude/scripts/check-boundaries.sh \"$FILE_PATH\"",
  "description": "Verify architectural layer boundaries"
}
```

**Script template:**

```bash
#!/bin/bash
# .claude/scripts/check-boundaries.sh
# Verify import boundaries per ARCHITECTURE.md
set -euo pipefail

FILE="${1:?Usage: check-boundaries.sh <file>}"

# Rules generated by the configurator from plan.md architectural decisions.
# Each rule has 3 fields separated by the first two semicolons:
#   SOURCE_DIR ; FORBIDDEN_PATTERN ; EXPLANATION
# Semicolons in regex are rare enough to be safe as delimiters (unlike |).
# The configurator populates these from the project's layer structure.
RULES=(
  # Examples (replaced by configurator with project-specific rules):
  # "src/domain;android.content;Domain layer must be platform-independent"
  # "src/ui;src/repository;UI must not import repository directly — route through service"
  # "app/client;server-only;Client components cannot use server-only modules"
)

if [ ${#RULES[@]} -eq 0 ]; then
  echo "WARNING: check-boundaries.sh has no rules configured. Edit the RULES array."
  exit 0
fi

for rule in "${RULES[@]}"; do
  DIR="${rule%%;*}"; rest="${rule#*;}"
  PATTERN="${rest%%;*}"; EXPLANATION="${rest#*;}"

  if [[ "$FILE" == *"$DIR"* ]] && grep -qE "$PATTERN" "$FILE" 2>/dev/null; then
    echo "ARCHITECTURE VIOLATION in $FILE"
    echo ""
    echo "  Layer: $DIR"
    echo "  Forbidden pattern: $PATTERN"
    echo ""
    echo "Remediation:"
    echo "  $EXPLANATION"
    echo "  See docs/ARCHITECTURE.md for the dependency graph."
    exit 1
  fi
done
```

**When to use:** Balanced and thorough quality bars, when the plan defines clear
architectural layers. The configurator reads `plan.md` and generates the RULES array
with project-specific boundary checks. Skip for small projects without layering.

### Convention Guard (PostToolUse)

Verifies project-specific conventions are maintained: naming patterns, file structure,
required patterns (e.g., all API endpoints return an envelope, all errors use a shared
error type).

```json
{
  "matcher": "Edit|Write",
  "command": ".claude/scripts/check-conventions.sh \"$FILE_PATH\"",
  "description": "Verify naming conventions and structural patterns"
}
```

**Script template:**

```bash
#!/bin/bash
# .claude/scripts/check-conventions.sh
# Verify project conventions
set -euo pipefail

FILE="${1:?Usage: check-conventions.sh <file>}"

# Helper: match a file path against a glob pattern.
# Uses 'case' because [[ == ]] does not support ** glob expansion.
matches_glob() {
  # shellcheck disable=SC2254
  case "$1" in $2) return 0 ;; *) return 1 ;; esac
}

# Rules generated by the configurator from plan.md conventions + existing linter analysis.
# Each rule has 3 fields separated by the first two semicolons:
#   FILE_GLOB ; REQUIRED_PATTERN ; EXPLANATION
# These check for patterns that SHOULD be present (positive assertions).
# Note: use simple globs (src/api/*.ts, *.test.ts) — ** is not supported.
REQUIRED_RULES=(
  # Examples (replaced by configurator):
  # "src/api/*.ts;return.*\{ data.*error.*meta \};All API endpoints must return { data, error, meta } envelope"
  # "*.test.ts;describe\(;Test files must use describe() blocks"
)

# Each rule has 3 fields separated by the first two semicolons:
#   FILE_GLOB ; FORBIDDEN_PATTERN ; EXPLANATION
# These check for patterns that must NOT be present (negative assertions).
FORBIDDEN_RULES=(
  # Examples (replaced by configurator):
  # "*.ts;console\.log;Use structured logger instead of console.log"
  # "src/domain/*.ts;throw new Error\(;Domain layer must use typed DomainError, not bare Error"
)

if [ ${#REQUIRED_RULES[@]} -eq 0 ] && [ ${#FORBIDDEN_RULES[@]} -eq 0 ]; then
  echo "WARNING: check-conventions.sh has no rules configured. Edit the RULES arrays."
  exit 0
fi

for rule in "${REQUIRED_RULES[@]}"; do
  GLOB="${rule%%;*}"; rest="${rule#*;}"
  PATTERN="${rest%%;*}"; EXPLANATION="${rest#*;}"

  if matches_glob "$FILE" "$GLOB" && ! grep -qE "$PATTERN" "$FILE" 2>/dev/null; then
    echo "CONVENTION VIOLATION in $FILE"
    echo "  Missing required pattern: $PATTERN"
    echo ""
    echo "Remediation:"
    echo "  $EXPLANATION"
    exit 1
  fi
done

for rule in "${FORBIDDEN_RULES[@]}"; do
  GLOB="${rule%%;*}"; rest="${rule#*;}"
  PATTERN="${rest%%;*}"; EXPLANATION="${rest#*;}"

  if matches_glob "$FILE" "$GLOB" && grep -qE "$PATTERN" "$FILE" 2>/dev/null; then
    MATCH=$(grep -nE "$PATTERN" "$FILE" | head -3)
    echo "CONVENTION VIOLATION in $FILE"
    echo "  Forbidden pattern found: $PATTERN"
    echo "  $MATCH"
    echo ""
    echo "Remediation:"
    echo "  $EXPLANATION"
    exit 1
  fi
done
```

**When to use:** Thorough quality bar. Best when the project has documented conventions
in CLAUDE.md or plan.md. The configurator extracts conventions and generates concrete
regex rules — generic rules (covered by standard linters) should not be duplicated here.

## Entropy Management

### Entropy Check (PostToolUse — Bash)

Counts completed features and emits a reminder when entropy management is due. This
mechanizes the cleanup cadence — instead of relying on the agent to remember a prose
recommendation, the hook fires at the right moment with actionable instructions. Uses
`PostToolUse` with a Bash matcher to detect completed commits.

```json
{
  "matcher": "Bash",
  "command": ".claude/scripts/entropy-check.sh",
  "description": "Check if entropy management cleanup is due"
}
```

**Script template:**

```bash
#!/bin/bash
# .claude/scripts/entropy-check.sh
# Emit entropy management reminders at configured intervals
#
# NOTE: no set -euo pipefail — this script uses || fallbacks for missing files
# and must never abort on jq errors. All commands have explicit error handling.

FEATURE_LIST="{feature_dir}/.harness/feature-list.json"
CLEANUP_STATE="{feature_dir}/.harness/last-cleanup.json"

# Guard: verify placeholders were filled by the configurator
if [[ "$FEATURE_LIST" == *"{"* ]]; then
  echo "ERROR: entropy-check.sh contains unfilled template placeholders. Re-run harness configurator."
  exit 0
fi

# Count completed features
COMPLETED=$(jq '[.features[] | select(.passes==true)] | length' "$FEATURE_LIST" 2>/dev/null || echo 0)

# Read cleanup thresholds
NEXT_MINOR=$(jq -r '.next_minor_at // 5' "$CLEANUP_STATE" 2>/dev/null || echo 5)
NEXT_MAJOR=$(jq -r '.next_major_at // 10' "$CLEANUP_STATE" 2>/dev/null || echo 10)

if [ "$COMPLETED" -ge "$NEXT_MAJOR" ]; then
  echo "ENTROPY MANAGEMENT DUE (major) — $COMPLETED features completed"
  echo ""
  echo "Actions required before next feature:"
  # NOTE: configurator should remove the lint line below if no lint command was discovered
  echo "  1. Run full test suite + lint: {test_command} && {lint_command}"
  echo "  2. Fix accumulated warnings (check for new lint violations)"
  echo "  3. Review docs/ARCHITECTURE.md — does it still match the code?"
  echo "  4. Update .harness/quality-score.json dimensions"
  echo "  5. Check for dead code: unused exports, unreferenced functions"
  echo "  6. Update .harness/last-cleanup.json with new thresholds"
  echo "  7. Commit: chore: entropy management after $COMPLETED features"
  # Non-blocking: the agent sees this and should act on it
elif [ "$COMPLETED" -ge "$NEXT_MINOR" ]; then
  echo "ENTROPY CHECK (minor) — $COMPLETED features since setup"
  echo "  Consider: review docs/ARCHITECTURE.md for drift, update quality-score.json"
fi
```

**When to use:** Balanced and thorough quality bars. The thresholds are stored in
`last-cleanup.json` (see `harness-components.md` Section 2d) and advance after each
cleanup pass — so the hook tracks absolute progress, not relative intervals.

**Non-blocking by design:** The hook prints a reminder but exits 0. This avoids
blocking commits during active development — the agent reads the output and should
schedule cleanup as its next action, but isn't forced to stop mid-feature.

## Compound Learning

### Compound Inject (SessionStart)

Injects ALL accumulated implementation learnings into the session context at startup.
Also detects phase boundaries (all tasks in a phase complete) and signals when learnings
should be reviewed for promotion to CLAUDE.md "Known Patterns". See
`harness-components.md` Section 2g for the learnings template, promotion protocol, and
quality-bar adaptation.

```json
{
  "matcher": "",
  "command": ".claude/scripts/compound-inject.sh",
  "description": "Inject implementation learnings and detect phase boundaries"
}
```

**Script template:**

```bash
#!/bin/bash
# .claude/scripts/compound-inject.sh
# Inject all learnings + detect phase-boundary promotion opportunity
#
# NOTE: no set -euo pipefail — this script uses || fallbacks for missing files
# and must never abort on jq errors. All commands have explicit error handling.

LEARNINGS="{feature_dir}/.harness/learnings.md"
FEATURE_LIST="{feature_dir}/.harness/feature-list.json"
LAST_PROMOTION="{feature_dir}/.harness/last-promotion.txt"
SKIP_FILE="{feature_dir}/.harness/learnings-skip.md"

# Guard: verify placeholders were filled by the configurator
if [[ "$LEARNINGS" == *"{"* ]]; then
  echo "ERROR: compound-inject.sh contains unfilled template placeholders. Re-run harness configurator."
  exit 0
fi

# --- Clean skip file from previous session ---
if [ -f "$SKIP_FILE" ]; then
  rm -f "$SKIP_FILE"
fi

# --- Inject learnings ---
if [ -f "$LEARNINGS" ]; then
  # Count entries by their ### LNNN headers (more reliable than --- separators)
  # NOTE: grep -c exits 1 when count is 0; use || true (not || echo 0) to avoid
  # appending a second "0" to stdout which would break numeric tests.
  ENTRY_COUNT=$(grep -c '^### L[0-9]' "$LEARNINGS" 2>/dev/null || true)
  ENTRY_COUNT=${ENTRY_COUNT:-0}
  if [ "$ENTRY_COUNT" -gt 0 ]; then
    echo "[Compound] $ENTRY_COUNT learnings loaded from previous sessions:"
    echo ""
    cat "$LEARNINGS"
    echo ""
  fi
fi

# --- Detect phase boundary ---
if [ -f "$FEATURE_LIST" ]; then
  # Get all distinct phases
  PHASES=$(jq -r '[.features[].phase] | unique | .[]' "$FEATURE_LIST" 2>/dev/null)

  # Check if any phase is fully complete (all tasks pass)
  COMPLETE_PHASES=""
  while IFS= read -r phase; do
    [ -z "$phase" ] && continue
    TOTAL=$(jq --arg p "$phase" '[.features[] | select(.phase==$p)] | length' "$FEATURE_LIST" 2>/dev/null || echo 0)
    PASSED=$(jq --arg p "$phase" '[.features[] | select(.phase==$p and .passes==true)] | length' "$FEATURE_LIST" 2>/dev/null || echo 0)
    if [ "$TOTAL" -gt 0 ] && [ "$TOTAL" -eq "$PASSED" ]; then
      COMPLETE_PHASES="$COMPLETE_PHASES  - $phase ($TOTAL tasks)
"
    fi
  done <<< "$PHASES"

  if [ -n "$COMPLETE_PHASES" ]; then
    # Count complete phases (not tasks) to detect NEW phase completions.
    # Using phase count avoids over-triggering: completing a task within
    # an already-complete phase won't change this count.
    COMPLETE_PHASE_COUNT=$(printf '%s' "$COMPLETE_PHASES" | grep -c '^ ' || true)
    COMPLETE_PHASE_COUNT=${COMPLETE_PHASE_COUNT:-0}
    LAST_PROMOTED_PHASES=$(cat "$LAST_PROMOTION" 2>/dev/null || echo "0")
    if [ "$COMPLETE_PHASE_COUNT" != "$LAST_PROMOTED_PHASES" ]; then
      echo "[Compound] PHASE BOUNDARY — completed phases detected:"
      printf '%s' "$COMPLETE_PHASES"
      echo "MANDATORY: Before starting new work, review .harness/learnings.md for promotion:"
      echo "  1. Read each learning entry"
      echo "  2. For each: would a future agent on a DIFFERENT feature need this?"
      echo "     YES → Add to CLAUDE.md '## Known Patterns' section"
      echo "     NO  → Leave in learnings.md (feature-scoped)"
      echo "  3. Write complete-phase-count to .harness/last-promotion.txt"
      echo ""
    fi
  fi
fi
```

**When to use:** Always when compound learning is enabled. Lightweight (reads 2 files,
no builds). SessionStart hooks fire once per session — zero per-message overhead.

### Compound Gate (PreToolUse — Bash)

Blocks commits unless the agent has addressed learnings — either by appending a new
entry to `learnings.md` or creating a skip file with a reason. Follows the same
composition pattern as the test-gate hook: both match `Bash` and check for `git commit`,
both must pass independently for the commit to proceed.

```json
{
  "matcher": "Bash",
  "command": ".claude/scripts/compound-gate.sh",
  "description": "Ensure implementation learnings are captured before commit"
}
```

**Script template:**

```bash
#!/bin/bash
# .claude/scripts/compound-gate.sh
# Block commits unless learnings.md was updated or skip reason exists
#
# Composition: this hook and test-gate both match Bash/git-commit.
# Claude Code runs all matching hooks independently — both must exit 0.

LEARNINGS="{feature_dir}/.harness/learnings.md"
SKIP_FILE="{feature_dir}/.harness/learnings-skip.md"

# Guard: verify placeholders were filled
if [[ "$LEARNINGS" == *"{"* ]]; then
  exit 0
fi

# Read stdin to detect git commit commands (same pattern as test-gate)
COMMAND=$(cat | jq -r '.tool_input.command // empty')
[[ "$COMMAND" == git\ commit* ]] || exit 0

# Check 1: learnings.md in staging area?
# NOTE: avoid grep -c || echo 0 — grep -c exits 1 on zero matches, causing
# || echo 0 to append a second "0" and break numeric tests. Use grep -q instead.
LEARNINGS_STAGED=0
if git diff --cached --name-only 2>/dev/null | grep -q 'learnings\.md'; then
  LEARNINGS_STAGED=1
fi

# Check 2: skip file exists with content?
SKIP_EXISTS=0
if [ -f "$SKIP_FILE" ] && [ -s "$SKIP_FILE" ]; then
  SKIP_EXISTS=1
fi

if [ "$LEARNINGS_STAGED" -eq 0 ] && [ "$SKIP_EXISTS" -eq 0 ]; then
  echo "COMPOUND GATE: Learnings not addressed"
  echo ""
  echo "Before committing, you must either:"
  echo ""
  echo "  Option A — Append a learning to $LEARNINGS:"
  echo "    ---"
  echo "    ### LNNN — Brief title"
  echo "    **Session**: $(date +%Y-%m-%d) | **Task**: <current task ID>"
  echo "    **Type**: Decision | Workaround | Gotcha | Dependency | Finding"
  echo "    {What you learned and why it matters}"
  echo "    **Applies when**: {conditions where this is relevant}"
  echo ""
  echo "  Option B — Skip with reason (for trivial changes):"
  echo "    Write a 1-line reason to $SKIP_FILE"
  echo "    Example: echo 'config-only change, no new insights' > $SKIP_FILE"
  echo ""
  echo "Then retry the commit."
  exit 1
fi
```

**When to use:** Balanced and thorough quality bars. For fast iteration, make the gate
advisory (exit 0 always, print reminder only). The skip mechanism prevents friction on
trivial commits while ensuring the agent at least considers whether there are learnings.

**Composition with test-gate:** Both hooks match `Bash` and detect `git commit`. Claude
Code pipes the same stdin JSON to each. If test-gate fails, compound-gate output is also
visible — the agent fixes both in one retry. No ordering dependency between them.

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
