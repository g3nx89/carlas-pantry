# Development Protocols

Templates read by the harness configurator at Stage 2 to generate project-local files:
gate scripts, the SessionStart hook, and the task state machine. All `{PLACEHOLDER}` values
are filled from `analysis.json` at generation time.

---

## Section 1: Quality Bar Resolution

### 1a. Dimension Mapping Table

The quality bar preset maps to four enforcement dimensions. Each dimension is resolved
independently and can be overridden by the user during the Stage 1 interview.

| Dimension | fast | balanced | thorough |
|-----------|------|----------|----------|
| `tdd_enforcement` | off | advisory | strict |
| `review_granularity` | per-sprint | per-phase | per-task |
| `test_delta_gate` | off | warning | blocking |
| `anti_rationalizations` | none | meta-warning | full |

**tdd_enforcement:**
- `off` — no commit gate for test files. Coder can commit production code without tests.
- `advisory` — gate runs, prints a warning, exits 0. Does not block the commit.
- `strict` — gate runs, exits 1 if no test file found for new production file. Blocks the commit. Refactor commits bypass this gate (see Section 2a).

**review_granularity:**
- `per-sprint` — no state machine, no review artifacts gate. The eval loop handles review at sprint boundaries.
- `per-phase` — no per-task state machine. Tasks commit freely within a phase. At phase boundary, the agent runs review and writes phase review artifacts. Evidence gate checks `.harness/reviews/phase-{N}/`.
- `per-task` — full state machine per task. Each task must pass spec-compliance and code-quality review before the agent can mark it done.

**test_delta_gate:**
- `off` — test delta gate script is not generated.
- `warning` — gate exits 0 with a warning when no matching test file is found.
- `blocking` — gate exits 1, blocking the commit.

**anti_rationalizations:**
- `none` — no rationalization messages in any gate output.
- `meta-warning` — balanced mode: gates include a short rationalization-alert block. SessionStart context includes a condensed alert list.
- `full` — thorough mode: gates include the full three-message anti-rationalization block. SessionStart context includes the full rationalization alert and Iron Laws.

### 1b. Override Handling

During the Stage 1 interview, the user may accept the preset or override individual dimensions.
Parse their response as follows:

1. Start with the preset's resolved values from the table above.
2. For each dimension the user mentions explicitly, replace only that dimension's value.
3. Write the resolved object to `analysis.json`.

Example: user says "thorough but review only per-sprint"

The preset `thorough` resolves to:
- `tdd_enforcement: strict`
- `review_granularity: per-task`
- `test_delta_gate: blocking`
- `anti_rationalizations: full`

The override replaces `review_granularity` only. Store in `analysis.json`:

```json
{
  "quality_dimensions": {
    "preset": "thorough",
    "overrides": { "review_granularity": "per-sprint" },
    "resolved": {
      "tdd_enforcement": "strict",
      "review_granularity": "per-sprint",
      "test_delta_gate": "blocking",
      "anti_rationalizations": "full"
    }
  }
}
```

### 1c. analysis.json Additions Template

Add this block alongside the existing `analysis.json` content written in Stage 1:

```json
{
  "quality_dimensions": {
    "preset": "{QUALITY_PRESET}",
    "overrides": {},
    "resolved": {
      "tdd_enforcement": "{TDD_ENFORCEMENT}",
      "review_granularity": "{REVIEW_GRANULARITY}",
      "test_delta_gate": "{TEST_DELTA_GATE}",
      "anti_rationalizations": "{ANTI_RATIONALIZATIONS}"
    }
  }
}
```

Placeholders filled from interview responses:
- `{QUALITY_PRESET}` — `fast`, `balanced`, or `thorough`
- `{TDD_ENFORCEMENT}` — `off`, `advisory`, or `strict`
- `{REVIEW_GRANULARITY}` — `per-sprint`, `per-phase`, or `per-task`
- `{TEST_DELTA_GATE}` — `off`, `warning`, or `blocking`
- `{ANTI_RATIONALIZATIONS}` — `none`, `meta-warning`, or `full`

If the user provided overrides, populate the `overrides` object with only the overridden keys.

---

## Section 2: Gate Script Templates

All scripts follow this structure: `#!/bin/bash` header, `set -euo pipefail`, stdin JSON
parsed with `jq`, early-exit on irrelevant tool calls, check logic, anti-rationalization
messages on failure, skill pointer on failure.

Scripts are generated into `.claude/scripts/` and registered in `.claude/settings.json`
under the appropriate hook event. Do not generate a script if its controlling dimension
resolves to `off`.

### 2a. verify-test-delta.sh (L1 — Test Completeness Gate)

**Hook:** `PreToolUse` — `matcher: "Bash"` — see `hooks-catalog.md` "Development Protocol Gates"
**Generated when:** `test_delta_gate` is `warning` or `blocking`

```bash
#!/bin/bash
# .claude/scripts/verify-test-delta.sh
# L1 — Test Completeness Gate
# Checks that new production files have a corresponding test file.

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only run on git commit
[[ "$COMMAND" == git\ commit* ]] || exit 0

# Refactor bypass: refactor commits skip this gate unless tdd_enforcement is strict
COMMIT_MSG=$(echo "$COMMAND" | sed 's/.*-m[[:space:]]*//' | tr -d '"'"'" | head -c 50)
if [[ "$COMMIT_MSG" == refactor:* ]] && [[ "{TDD_ENFORCEMENT}" != "strict" ]]; then
  exit 0
fi

# Pattern variables — filled from analysis.json at generation time.
# Values must be valid Extended Regular Expressions (ERE).
EXCLUDE_RE='{EXCLUDE_PATTERNS}'
TEST_RE='{TEST_FILE_PATTERN}'
PROD_RE='{PROD_FILE_PATTERN}'

# Collect changed files
STAGED=$(git diff --cached --name-only)

# Count new production files (excluding config, types, docs)
PROD_COUNT=0
TEST_COUNT=0

while IFS= read -r file; do
  [[ -z "$file" ]] && continue

  # Skip excluded patterns
  if echo "$file" | grep -qE "$EXCLUDE_RE"; then
    continue
  fi

  if echo "$file" | grep -qE "$TEST_RE"; then
    TEST_COUNT=$((TEST_COUNT + 1))
  elif echo "$file" | grep -qE "$PROD_RE"; then
    PROD_COUNT=$((PROD_COUNT + 1))
  fi
done <<< "$STAGED"

# No production files changed — nothing to check
if [[ "$PROD_COUNT" -eq 0 ]]; then
  exit 0
fi

# Production files changed but no test files
if [[ "$TEST_COUNT" -eq 0 ]]; then
  echo ""
  echo "TEST COVERAGE GAP: $PROD_COUNT production file(s) changed, 0 test files staged."
  echo ""
  echo "Production files changed:"
  echo "$STAGED" | grep -E "$PROD_RE" | grep -vE "$EXCLUDE_RE" | sed 's/^/  /'
  echo ""

  if [[ "{TDD_ENFORCEMENT}" == "strict" ]]; then
    echo "Common rationalizations at this point:"
    echo "  'Too simple to test'      -> Simple code breaks. Test takes 30 seconds."
    echo "  'I'll test after'         -> Tests written after pass immediately -- prove nothing."
    echo "  'Already tested manually' -> Ad-hoc != systematic. No record, can't re-run."
    echo ""
    echo "Invoke product-implementation:tdd for the full TDD protocol."
    exit 1
  else
    echo "WARNING: Commit allowed (advisory mode), but test coverage is expected."
    echo "Add tests before marking this task complete."
    exit 0
  fi
fi

exit 0
```

Placeholders filled from `analysis.json`:
- `{TDD_ENFORCEMENT}` — from `quality_dimensions.resolved.tdd_enforcement`
- `{TEST_FILE_PATTERN}` — e.g., `\.(test|spec)\.(ts|js|tsx|jsx)$` or `_test\.py$`
- `{PROD_FILE_PATTERN}` — e.g., `\.(ts|js|tsx|jsx)$` (excluding test files)
- `{EXCLUDE_PATTERNS}` — e.g., `\.(json|yaml|md)$|types\.ts$|config\.ts$`

### 2b. gate-commit-on-state.sh (L2 — State-Aware Commit Gate)

**Hook:** `PreToolUse` — `matcher: "Bash"` — see `hooks-catalog.md` "State-Aware Commit Gate"
**Generated when:** `review_granularity` is `per-task` ONLY
**Depends on:** `.harness/task-state.json`

```bash
#!/bin/bash
# .claude/scripts/gate-commit-on-state.sh
# L2 — State-Aware Commit Gate
# Blocks commits when a review is pending for the current task.

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only run on git commit
[[ "$COMMAND" == git\ commit* ]] || exit 0

# Read task state
STATE_FILE=".harness/task-state.json"
if [[ ! -f "$STATE_FILE" ]]; then
  # No state file means no per-task tracking active — allow commit
  exit 0
fi

STATE=$(jq -r '.state // empty' "$STATE_FILE")
CURRENT_TASK=$(jq -r '.current_task // empty' "$STATE_FILE")

# Allow commit if implementing or approved — but ALWAYS run tests first.
# This gate REPLACES the basic test gate, so test execution happens here.
if [[ "$STATE" == "implementing" ]] || [[ "$STATE" == "approved" ]]; then
  # Run test suite (same as verify-tests-on-commit.sh)
  echo "Running test suite before commit..."
  if ! {TEST_COMMAND}; then
    echo "COMMIT BLOCKED: Tests failed. Fix failing tests before committing."
    exit 1
  fi
  exit 0
fi

# Block if review is pending
if [[ "$STATE" == "needs-spec-review" ]] || [[ "$STATE" == "needs-quality-review" ]]; then
  echo ""
  echo "COMMIT BLOCKED: Task $CURRENT_TASK is in state '$STATE'."
  echo ""
  echo "A review must be completed before you can commit additional code."
  echo "Current state: $STATE"
  echo ""
  echo "Common rationalizations at this point:"
  echo "  'Code is simple, doesn't need review'  -> Simple code has simple bugs. Review catches them."
  echo "  'I already self-reviewed'               -> Self-review complements peer review, doesn't replace it."
  echo "  'Review will slow me down'              -> Review catches issues now. Debugging catches them later."
  echo ""
  echo "Invoke product-implementation:code-review for the review protocol."
  exit 1
fi

# Unknown state — warn but allow
echo "WARNING: Unknown task state '$STATE'. Allowing commit, but check task-state.json."
exit 0
```

### 2c. gate-feature-list-on-state.sh (L3 — Evidence Gate)

**Hook:** `PreToolUse` — `matcher: "Edit|Write"`
**Generated when:** `review_granularity` is `per-task` or `per-phase`
**Depends on:** review artifacts in `.harness/reviews/`

```bash
#!/bin/bash
# .claude/scripts/gate-feature-list-on-state.sh
# L3 — Evidence Gate
# Blocks marking a task/phase done without review artifacts and clean source.

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only run when writing feature-list.json
if [[ "$FILE_PATH" != *"feature-list.json" ]]; then
  exit 0
fi

REVIEW_GRANULARITY="{REVIEW_GRANULARITY}"
REVIEWS_DIR=".harness/reviews"

check_review_artifact() {
  local artifact_path="$1"
  local label="$2"

  if [[ ! -f "$artifact_path" ]]; then
    echo "BLOCKED: Missing review artifact: $artifact_path"
    echo "  ($label review has not been completed)"
    return 1
  fi

  local verdict
  verdict=$(jq -r '.verdict // empty' "$artifact_path")
  if [[ "$verdict" != "pass" ]]; then
    echo "BLOCKED: $label review verdict is '$verdict' (expected 'pass')."
    echo "  Artifact: $artifact_path"
    return 1
  fi

  return 0
}

BLOCKED=0

if [[ "$REVIEW_GRANULARITY" == "per-task" ]]; then
  STATE_FILE=".harness/task-state.json"
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "BLOCKED: .harness/task-state.json not found. Cannot verify review completion."
    BLOCKED=1
  else
    TASK_ID=$(jq -r '.current_task // empty' "$STATE_FILE")
    if [[ -z "$TASK_ID" ]]; then
      echo "BLOCKED: current_task not set in task-state.json."
      BLOCKED=1
    else
      TASK_REVIEW_DIR="$REVIEWS_DIR/$TASK_ID"
      check_review_artifact "$TASK_REVIEW_DIR/spec-review.json" "Spec-compliance" || BLOCKED=1
      check_review_artifact "$TASK_REVIEW_DIR/quality-review.json" "Code-quality" || BLOCKED=1
    fi
  fi

elif [[ "$REVIEW_GRANULARITY" == "per-phase" ]]; then
  # Determine current phase from feature-list.json (first incomplete feature's phase)
  if [[ ! -f ".harness/feature-list.json" ]]; then
    echo "BLOCKED: .harness/feature-list.json not found."
    BLOCKED=1
  else
    PHASE_N=$(jq -r '[.features[] | select(.passes == false) | .phase] | first // empty' .harness/feature-list.json)
    if [[ -z "$PHASE_N" ]]; then
      # All features pass — allow
      exit 0
    fi
    PHASE_REVIEW_DIR="$REVIEWS_DIR/phase-$PHASE_N"
    check_review_artifact "$PHASE_REVIEW_DIR/spec-review.json" "Phase $PHASE_N spec-compliance" || BLOCKED=1
    check_review_artifact "$PHASE_REVIEW_DIR/quality-review.json" "Phase $PHASE_N code-quality" || BLOCKED=1
  fi
fi

# Check that source code is committed (exclude .harness/ from dirty-tree check)
DIRTY=$(git status --porcelain | grep -v '\.harness/' | head -1 || true)
if [[ -n "$DIRTY" ]]; then
  echo "BLOCKED: Uncommitted source code changes detected."
  echo "  Commit your code first (which triggers the test gate), then mark complete."
  BLOCKED=1
fi

if [[ "$BLOCKED" -eq 1 ]]; then
  echo ""
  echo "Common rationalizations at this point:"
  echo "  'Should work now'    -> Run the verification. 'Should' is not evidence."
  echo "  'I'm confident'      -> Confidence != proof. Run the tests."
  echo "  'Just this last one' -> Especially this one. Verify."
  echo ""
  echo "Invoke product-implementation:verification for the verification protocol."
  exit 1
fi

exit 0
```

Placeholders filled from `analysis.json`:
- `{REVIEW_GRANULARITY}` — from `quality_dimensions.resolved.review_granularity`

### 2d. inject-protocols.sh (SessionStart Hook)

**Hook:** `SessionStart` — `matcher: "startup|clear|compact|resume"`
**Generated always** (adapts content by quality bar)
**Session-startup integration:** see `harness-components.md` Section 2d for checklist step

Reads `analysis.json` at session start and injects quality-bar-appropriate context
into the agent's working memory via `hookSpecificOutput`.

```bash
#!/bin/bash
# .claude/scripts/inject-protocols.sh
# SessionStart hook — injects development context scaled to the quality bar.

set -euo pipefail

ANALYSIS_FILE=".harness/analysis.json"
if [[ ! -f "$ANALYSIS_FILE" ]]; then
  exit 0
fi

TDD_ENFORCEMENT=$(jq -r '.quality_dimensions.resolved.tdd_enforcement // "off"' "$ANALYSIS_FILE")
REVIEW_GRANULARITY=$(jq -r '.quality_dimensions.resolved.review_granularity // "per-sprint"' "$ANALYSIS_FILE")
ANTI_RATIONALIZATIONS=$(jq -r '.quality_dimensions.resolved.anti_rationalizations // "none"' "$ANALYSIS_FILE")
BUILD_COMMAND=$(jq -r '.commands.build // "npm run build"' "$ANALYSIS_FILE")
TEST_COMMAND=$(jq -r '.commands.test // "npm test"' "$ANALYSIS_FILE")

build_fast_content() {
  cat <<EOF
Build: $BUILD_COMMAND
Test: $TEST_COMMAND
Progress: .harness/feature-list.json
If product-implementation plugin is available, invoke skills for guidance.
EOF
}

build_balanced_content() {
  cat <<EOF
$(build_fast_content)

## Development Protocol
Review required at $REVIEW_GRANULARITY boundaries.
Before marking tasks done, ensure review artifacts exist in .harness/reviews/.

## Rationalization Alert
If you catch yourself thinking any of these, STOP -- you are rationalizing:
- "Just this once" / "This is different because..."
- "Too simple to..." / "I'll do it after..."
- "Should work now" / "I'm confident it..."
Read the relevant skill before proceeding.
EOF
}

build_thorough_content() {
  cat <<EOF
$(build_balanced_content)

## Iron Laws
1. NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
2. NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
3. NO TASK PROGRESSION WITHOUT REVIEW APPROVAL

## Per-Task Flow
1. IMPLEMENT: TDD (RED->GREEN->REFACTOR), commit when green
2. REVIEW: spec compliance -> code quality (both must pass)
3. APPROVE: review artifacts written with verdict: "pass"
4. COMPLETE: update feature-list.json

## Active Gates
- verify-test-delta.sh: blocks commits without tests (BLOCKING)
- gate-commit-on-state.sh: blocks commits during pending review
- gate-feature-list-on-state.sh: blocks marking done without review + clean source
EOF
}

# Select content by quality bar
if [[ "$TDD_ENFORCEMENT" == "strict" ]] || [[ "$REVIEW_GRANULARITY" == "per-task" ]]; then
  CONTENT=$(build_thorough_content)
elif [[ "$TDD_ENFORCEMENT" == "advisory" ]] || [[ "$REVIEW_GRANULARITY" == "per-phase" ]]; then
  CONTENT=$(build_balanced_content)
else
  CONTENT=$(build_fast_content)
fi

# Escape content for JSON string embedding
ESCAPED_CONTENT=$(printf '%s' "$CONTENT" | python3 -c "
import sys, json
print(json.dumps(sys.stdin.read())[1:-1])
")

printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$ESCAPED_CONTENT"
```

---

## Section 3: Task State Machine & Review Artifacts

See also `harness-components.md` Section 2d for the task-state tracking template and
review artifacts integration in the session-startup checklist.

### 3a. task-state.json Schema (per-task mode ONLY)

Generated at `.harness/task-state.json` when `review_granularity` is `per-task`.
Not generated for `per-sprint` or `per-phase` modes.

```json
{
  "schema_version": 1,
  "current_task": "task-2.1",
  "state": "implementing",
  "history": [
    { "task": "task-1.1", "state": "approved", "timestamp": "2024-01-15T10:30:00Z" }
  ]
}
```

NOTE: `task-state.json` is a CONVENIENCE TRACKER for the agent's behavioral layer.
It is NOT the gate's source of truth.
`gate-feature-list-on-state.sh` verifies REVIEW ARTIFACTS directly (see Section 3e).
`gate-commit-on-state.sh` reads `task-state.json` only to block commits during pending review.

### 3b. Valid State Transitions (per-task mode)

The agent transitions task-state.json manually as work progresses. Valid transitions:

```
implementing --> needs-spec-review
needs-spec-review --> needs-quality-review   (spec reviewer approves)
needs-spec-review --> implementing            (spec reviewer rejects -> fix loop)
needs-quality-review --> approved             (quality reviewer approves)
needs-quality-review --> implementing         (quality reviewer rejects -> fix loop)
approved --> implementing                     (next task starts)
```

When a reviewer rejects, the agent returns to `implementing`, addresses findings, commits
the fix, and re-submits for review. There is no limit on fix loops — the gate holds until
both reviews pass.

The `history` array is append-only. Never overwrite a previous history entry.

### 3c. Granularity Modes

**per-sprint (fast preset default):**
- No state machine generated.
- No review artifacts gate generated.
- The existing eval loop (evaluation-loop.md) handles review at sprint boundaries.
- No `.harness/task-state.json` file.

**per-phase (balanced preset default):**
- No per-task state machine.
- Tasks commit freely within a phase — `gate-commit-on-state.sh` is not generated.
- At phase boundary, the agent runs spec-compliance and code-quality review and writes artifacts to `.harness/reviews/phase-{N}/`.
- `gate-feature-list-on-state.sh` is generated and checks phase artifacts.
- No `.harness/task-state.json` file.

**per-task (thorough preset default):**
- Full state machine generated (Section 3a).
- `gate-commit-on-state.sh` generated to block commits during pending reviews.
- `gate-feature-list-on-state.sh` generated to check per-task review artifacts.
- Review artifacts written to `.harness/reviews/{task_id}/`.

### 3d. Integration Points

| Component | Reads | Writes | Mode |
|-----------|-------|--------|------|
| `gate-commit-on-state.sh` | `.harness/task-state.json` | — | per-task only |
| `gate-feature-list-on-state.sh` | `.harness/reviews/{task_id or phase-N}/` | — | per-task, per-phase |
| Agent (behavioral layer) | — | `.harness/task-state.json` | per-task only |
| Review subagent | — | `.harness/reviews/{task_id or phase-N}/*.json` | per-task, per-phase |
| `inject-protocols.sh` | `.harness/analysis.json` | — | all modes |

Error messages in gate scripts redirect to skills when review artifacts are missing,
providing the agent with the exact next action rather than a bare failure.

### 3e. Review Artifact Schema

**Per-task paths:**
- `.harness/reviews/{task_id}/spec-review.json`
- `.harness/reviews/{task_id}/quality-review.json`

**Per-phase paths:**
- `.harness/reviews/phase-{N}/spec-review.json`
- `.harness/reviews/phase-{N}/quality-review.json`

Schema (same for both review types):

```json
{
  "schema_version": 1,
  "task_id": "task-2.1",
  "review_type": "spec-compliance",
  "reviewer": "subagent",
  "verdict": "pass",
  "timestamp": "2024-01-15T10:30:00Z",
  "findings": [
    {
      "severity": "important",
      "description": "Missing error handling for empty input",
      "file": "src/handler.ts:45"
    }
  ]
}
```

`review_type` values: `spec-compliance`, `code-quality`
`verdict` values: `pass`, `fail`
`severity` values: `critical`, `important`, `minor`

The gate checks `verdict == "pass"` only. The `findings` array is for agent guidance
during fix loops — a `pass` verdict with findings is valid (minor issues noted but not blocking).
A `fail` verdict blocks progression regardless of findings content.

### 3f. Dirty Tree Policy

The evidence gate must exclude `.harness/` from the dirty-tree check. Gate scripts
and review artifacts live in `.harness/` and should not block feature-list writes.

Pattern used in `gate-feature-list-on-state.sh`:

```bash
DIRTY=$(git status --porcelain | grep -v '\.harness/' | head -1 || true)
if [[ -n "$DIRTY" ]]; then
  echo "BLOCKED: Uncommitted source code changes detected."
  echo "Commit your code first (which triggers the test gate), then mark complete."
  exit 1
fi
```

The `grep -v '\.harness/'` pattern excludes any `git status` line mentioning a `.harness/` path,
regardless of status code (modified, added, deleted, renamed, untracked).
