# External CLI Agent Integration

Configure external CLI agents (Codex, Gemini) as independent evaluators and reviewers.
The harness sets up dispatch scripts and instruction files — it does NOT orchestrate
the agents at runtime. The user or Claude invokes them when needed.

## Why External Agents Matter

1. **Generator ≠ Evaluator** — The model that wrote the code should not be the sole judge.
   An external CLI agent (different model, different training) provides genuinely independent
   evaluation. This is the strongest form of the generator/evaluator split.

2. **Token distribution** — External CLI agents use their own subscriptions (Codex Pro,
   Gemini Pro), distributing the token load and cost across providers.

3. **Different perspectives** — Each model has different strengths: Codex excels at
   correctness/security review, Gemini at spec validation and pattern analysis.

## Detection

Check which CLI agents and plugins are available:

```bash
CODEX_AVAILABLE=$(command -v codex >/dev/null 2>&1 && echo true || echo false)
GEMINI_AVAILABLE=$(command -v gemini >/dev/null 2>&1 && echo true || echo false)

# Check if the OpenAI Codex Plugin for Claude Code is installed
# This provides /codex:review, /codex:adversarial-review, /codex:rescue, stop-gate
CODEX_PLUGIN=$(claude plugins list 2>/dev/null | grep -q "codex" && echo true || echo false)
```

Record results in `analysis.json` under `available_tools.cli_agents`. Include
`codex_plugin: true/false` — the plugin enables significantly richer integration.

---

## Codex Plugin (Preferred When Available)

If the OpenAI Codex Plugin (`codex-plugin-cc`) is installed, prefer its commands over
direct `codex exec` dispatch. The plugin provides persistent job tracking, structured
JSON output, adversarial review mode, and an optional automated evaluation gate — all
patterns that map directly onto the generator/evaluator harness.

### Why the Plugin is Better Than `codex exec`

| Aspect | `codex exec` (fallback) | Codex Plugin (`/codex:*`) |
|--------|------------------------|---------------------------|
| Job tracking | Ephemeral | Persistent IDs, status polling, result retrieval |
| Background execution | Manual | Built-in `--background` with `/codex:status` |
| Review output | Raw text | Structured JSON: verdict, findings[], severity, confidence |
| Adversarial mode | Not available | `/codex:adversarial-review` attacks assumptions |
| Thread resumption | Requires session ID | Auto-detects resumable threads |
| Stop gate | Not available | Automated review on every Claude stop |

### Review Commands

**Standard code review (after completing a feature):**
```
/codex:review --scope auto
```
Returns structured output: `verdict` (approve/needs-attention), `findings[]` with severity,
file paths, line numbers, confidence, and recommendations.

**Adversarial review (for thorough quality bar):**
```
/codex:adversarial-review --scope auto
```
Default skepticism — assumes failure until evidence proves otherwise. Attacks: auth/permissions,
data loss, race conditions, rollback safety, timeouts, version skew, schema drift. Only
reports material findings (not style, not speculative).

**Review against evaluation criteria:**
```
/codex:review --scope auto "Evaluate against criteria in .harness/eval-criteria.md. Grade each dimension 1-5."
```

### Rescue (Delegation to Codex)

For substantial debugging, investigation, or fix tasks — hand them to Codex instead of
doing everything in the Claude session:

```
/codex:rescue "Investigate why the login flow fails on token refresh. Check AuthRepository and TokenManager."
```

Key options:
- `--background` — run in background, check with `/codex:status`
- `--model spark` — use the faster Codex Spark model for simpler tasks
- `--effort high` — increase reasoning depth for complex problems
- `--resume` — continue a previous investigation thread

The rescue pattern is especially useful after an evaluation FAIL — hand the specific
failing criteria to Codex for independent debugging.

### Stop Gate — Automated Evaluation Hook

The most powerful integration: Codex automatically reviews every Claude response before
it's finalized. Enable it with:

```
/codex:setup --enable-review-gate
```

**How it works:**
1. Claude writes code and stops
2. Before the stop is accepted, the Codex stop-gate hook fires
3. Codex reviews Claude's changes and returns `ALLOW` or `BLOCK`
4. If `BLOCK`, Claude receives the feedback and must address the issues
5. This creates an automatic generator→evaluator loop within a single session

**When to configure the stop gate:**

| Quality Bar | Stop Gate |
|-------------|-----------|
| Fast iteration | Disabled — too much overhead |
| Balanced | Disabled by default; user enables for critical features |
| Thorough | Enabled — every code change gets adversarial review |

**Warning:** The stop gate can create long-running Claude/Codex loops and drain usage
limits. Only enable when actively monitoring the session or for critical features.
The harness should document this in the session-startup checklist as an opt-in step.

**Harness configuration:** When the stop gate is appropriate, add to `session-startup.md`:
```markdown
## Optional: Enable Codex stop gate for critical features
To get automatic adversarial review on every code change:
`/codex:setup --enable-review-gate`
Disable when done: `/codex:setup --disable-review-gate`
```

### Plugin Output Integration with Evaluation Reports

The plugin's structured JSON output maps directly to the evaluation report format:

```
Plugin output:          →  Evaluation report mapping:
verdict: "needs-attention"  →  Verdict: FAIL or REVISE
findings[].severity      →  Critical issues (critical/high) vs Advisory (medium/low)
findings[].file/line     →  Evidence location
findings[].recommendation →  Remediation guidance
findings[].confidence    →  Score calibration (high confidence = trust, low = verify)
```

When the plugin is available, the harness should note in `eval-criteria.md` that Codex
reviews produce structured findings that can be mapped to the per-criterion scores.

---

## Fallback: Direct CLI Invocation

When the Codex plugin is NOT installed, fall back to direct `codex exec` dispatch.
These patterns are also used by the review dispatch script (`.claude/scripts/external-review.sh`).

### Codex (via `codex exec`)

**Custom prompt (read-only, for review):**
```bash
echo "$PROMPT" | codex exec \
  --full-auto \
  --sandbox read-only \
  --ephemeral \
  -o "$OUTPUT_FILE" \
  -
```

Key flags:
- `--full-auto` — automatic execution without approval prompts
- `--sandbox read-only` — prevents any file modifications (safe for review)
- `--ephemeral` — don't persist session files to disk
- `-o $FILE` — write the agent's final message to a file (clean, no noise)
- `-` — read prompt from stdin

**Built-in code review (preferred for git-based reviews):**
```bash
codex exec review \
  --uncommitted \
  --full-auto \
  --ephemeral \
  -o "$OUTPUT_FILE" \
  "Additional instructions: evaluate against criteria in .harness/eval-criteria.md"
```

Review-specific flags:
- `--uncommitted` — review staged, unstaged, and untracked changes
- `--base <BRANCH>` — review changes against a base branch
- `--commit <SHA>` — review a specific commit
- `[PROMPT]` — custom review instructions (appended to built-in review prompt)

### Gemini

**Custom prompt (read-only, for review):**
```bash
gemini --approval-mode plan \
  -p "$PROMPT" \
  2>/dev/null \
  > "$OUTPUT_FILE"
```

Key flags:
- `--approval-mode plan` — read-only mode, no file modifications
- `-p "$PROMPT"` — non-interactive/headless mode
- `2>/dev/null` — **critical**: gemini outputs MCP initialization noise to stderr;
  without this redirect, the output file is polluted with hundreds of lines of
  "Registering notification handlers", "MCP context refresh", etc.

## What to Generate

### 1. Review Dispatch Script

Generate `.claude/scripts/external-review.sh`:

```bash
#!/bin/bash
# .claude/scripts/external-review.sh
# Dispatch code review to an external CLI agent
# Usage: external-review.sh <codex|gemini> [--uncommitted|--base BRANCH|files...]

set -euo pipefail

CLI="${1:?Usage: external-review.sh <codex|gemini> [--uncommitted|--base BRANCH|files...]}"
shift

FEATURE_DIR="{feature_dir}"
EVAL_CRITERIA="$FEATURE_DIR/.harness/eval-criteria.md"
REVIEW_OUTPUT="$FEATURE_DIR/.harness/last-review.md"
TIMEOUT=300  # 5 minutes

case "$CLI" in
  codex)
    if [ "${1:-}" = "--uncommitted" ] || [ "${1:-}" = "--base" ]; then
      # Use built-in code review (git-based)
      timeout "$TIMEOUT" codex exec review \
        "$@" \
        --full-auto \
        --ephemeral \
        -o "$REVIEW_OUTPUT" \
        "Evaluate against these criteria: $(cat "$EVAL_CRITERIA")" \
        || echo "[REVIEW TIMEOUT OR ERROR: exit $?]" >> "$REVIEW_OUTPUT"
    else
      # Custom file-based review
      PROMPT="You are reviewing code. Grade each dimension from 1-5 with evidence.

## Evaluation Criteria
$(cat "$EVAL_CRITERIA")

## Files to Review
$(for f in "$@"; do echo "### $f"; cat "$f" 2>/dev/null || echo "(not found)"; echo; done)

## Output Format
Per-dimension score (1-5) with evidence, then overall verdict: PASS or FAIL"

      echo "$PROMPT" | timeout "$TIMEOUT" codex exec \
        --full-auto \
        --sandbox read-only \
        --ephemeral \
        -o "$REVIEW_OUTPUT" \
        - \
        || echo "[REVIEW TIMEOUT OR ERROR: exit $?]" >> "$REVIEW_OUTPUT"
    fi
    ;;

  gemini)
    PROMPT="You are reviewing code. Grade each dimension from 1-5 with evidence.

## Evaluation Criteria
$(cat "$EVAL_CRITERIA")

## Files to Review
$(for f in "$@"; do echo "### $f"; cat "$f" 2>/dev/null || echo "(not found)"; echo; done)

## Output Format
Per-dimension score (1-5) with evidence, then overall verdict: PASS or FAIL"

    timeout "$TIMEOUT" gemini --approval-mode plan \
      -p "$PROMPT" \
      2>/dev/null \
      > "$REVIEW_OUTPUT" \
      || echo "[REVIEW TIMEOUT OR ERROR: exit $?]" >> "$REVIEW_OUTPUT"
    ;;

  *)
    echo "Unknown CLI: $CLI. Use 'codex' or 'gemini'."
    exit 1
    ;;
esac

echo "Review saved to: $REVIEW_OUTPUT"
echo "---"
cat "$REVIEW_OUTPUT"
```

### 2. CLI Instruction File (AGENTS.md / GEMINI.md)

If Codex or Gemini is available, generate a lean instruction file at the project root.
This file is read by the CLI agent when invoked in the project directory.

**AGENTS.md** (for Codex):

```markdown
# Project Instructions

## Overview
{1-2 sentence project description from plan.md}

## Architecture
See `docs/ARCHITECTURE.md` for system design.

## Build & Test
- Build: `{build_command}`
- Test: `{test_command}`
- Lint: `{lint_command}`

## Review Guidelines
When reviewing code, evaluate against the criteria in:
`{feature_dir}/.harness/eval-criteria.md`

Focus on: correctness, security, edge cases, and spec compliance.
Do not modify source code — only report findings.

## Conventions
{2-3 key conventions from CLAUDE.md}
```

**GEMINI.md** (for Gemini) — same structure, but note:
- Gemini has no MCP access — it relies on file reading only
- Gemini benefits from longer context — include more convention detail
- Gemini works well for spec validation and pattern consistency checks

### 3. Evaluation Criteria Update

When CLI agents are available, add this to `eval-criteria.md`:

```markdown
## External Review

Available CLI agents for independent evaluation:
- Codex: `.claude/scripts/external-review.sh codex --uncommitted`
- Gemini: `.claude/scripts/external-review.sh gemini src/changed-file.ts`

Recommended workflow:
1. Complete a feature (all acceptance criteria met, tests passing)
2. Run external review before marking `passes: true` in feature-list.json
3. Address any CRITICAL findings before proceeding
4. Advisory findings can be deferred to the next session
```

## Workflow Integration

### When to Use External Review

| Quality Bar | When to Review | Which CLI |
|------------|---------------|-----------|
| Fast iteration | End of each phase (batch review) | Either — whichever is faster |
| Balanced | After completing each feature | Alternate between Codex and Gemini |
| Thorough | After each feature + end of phase | Both — compare their findings |

## Configuration in analysis.json

```json
{
  "available_tools": {
    "cli_agents": {
      "codex": true,
      "gemini": true,
      "codex_plugin": true,
      "codex_version": "codex-cli 0.116.0",
      "gemini_version": "0.35.3"
    }
  },
  "harness_decisions": {
    "external_review": {
      "enabled": true,
      "strategy": "alternate",
      "frequency": "per_feature",
      "codex_method": "plugin",
      "stop_gate": false
    }
  }
}
```

## 3. UAT Dispatch — Testing the Running Application

External CLI agents can also evaluate by interacting with the running application, not
just reviewing code. This is distinct from code review (Section 2) — it tests the app
from a user's perspective.

### How It Works

CLI agents don't have MCP access, so they can't use Playwright or mobile-mcp directly.
Instead, UAT dispatch works by providing the CLI agent with:
1. **App state description** — screenshots, DOM snapshots, or UI hierarchy captured before dispatch
2. **Sprint contract criteria** — what to verify
3. **Instructions to produce a structured verdict**

The harness generates a script that captures app state, dispatches the CLI agent with that
context, and collects the verdict.

### UAT Dispatch Script

Generate `.claude/scripts/uat-dispatch.sh`:

```bash
#!/bin/bash
# .claude/scripts/uat-dispatch.sh
# Dispatch UAT evaluation to an external CLI agent
# Usage: uat-dispatch.sh <codex|gemini> <evidence-dir>
#
# Expects: app is already running, evidence-dir contains screenshots/snapshots

set -euo pipefail

CLI="${1:?Usage: uat-dispatch.sh <codex|gemini> <evidence-dir>}"
EVIDENCE_DIR="${2:?Provide evidence directory with screenshots/snapshots}"

FEATURE_DIR="{feature_dir}"
EVAL_CRITERIA="$FEATURE_DIR/.harness/eval-criteria.md"
SPRINT_CONTRACT="$FEATURE_DIR/.harness/sprint-contract.md"
UAT_REPORT="$FEATURE_DIR/.harness/evaluation-report.md"
TIMEOUT=600  # 10 minutes — UAT is more complex than code review

# Build context from captured evidence
EVIDENCE_LISTING=$(ls -1 "$EVIDENCE_DIR" 2>/dev/null | head -20)

PROMPT="You are a UAT evaluator. You are reviewing evidence captured from a running
application to determine whether it meets the acceptance criteria.

## Your Role
- Judge the implementation from a USER's perspective, not a developer's
- Be skeptical: the coder believes everything works. Your job is to verify.
- Score each criterion 1-5 with specific evidence
- Any blocking criterion below threshold = FAIL verdict

## Sprint Contract (what 'done' looks like)
$(cat "$SPRINT_CONTRACT" 2>/dev/null || echo "No sprint contract found")

## Evaluation Criteria
$(cat "$EVAL_CRITERIA")

## Evidence Available
The following evidence files were captured from the running application:
$EVIDENCE_LISTING

Review each screenshot/snapshot and check whether the acceptance criteria are met.
Look for: missing UI elements, incorrect data, broken layouts, non-functional interactions,
error states, missing loading indicators, accessibility issues.

## Output Format
Write a structured evaluation report:
1. Per-criterion score (1-5) with evidence reference
2. Critical issues (must fix)
3. Advisory issues (fix when convenient)
4. Overall verdict: PASS | FAIL | PARTIAL"

case "$CLI" in
  codex)
    echo "$PROMPT" | timeout "$TIMEOUT" codex exec \
      --full-auto \
      --sandbox read-only \
      --ephemeral \
      -o "$UAT_REPORT" \
      - \
      || echo "[UAT EVALUATION TIMEOUT OR ERROR: exit $?]" >> "$UAT_REPORT"
    ;;

  gemini)
    timeout "$TIMEOUT" gemini --approval-mode plan \
      -p "$PROMPT" \
      2>/dev/null \
      > "$UAT_REPORT" \
      || echo "[UAT EVALUATION TIMEOUT OR ERROR: exit $?]" >> "$UAT_REPORT"
    ;;

  *)
    echo "Unknown CLI: $CLI. Use 'codex' or 'gemini'."
    exit 1
    ;;
esac

echo "UAT evaluation saved to: $UAT_REPORT"
echo "---"
cat "$UAT_REPORT"
```

### Native vs CLI Evaluator for UAT

Native Claude evaluators interact with the running app in real time (via MCP tools). CLI
agents review evidence (screenshots, snapshots) captured beforehand. Use native for
interactive UAT, CLI for independent code review. When both are available, run both — they
catch different things.

See `evaluation-loop.md` Section 4c for the full capability comparison.

### Workflow Integration for UAT

| Quality Bar | UAT Strategy |
|------------|-------------|
| Fast iteration | No UAT — code review only |
| Balanced | Native evaluator UAT after each feature, CLI review end of phase |
| Thorough | Native UAT + CLI UAT after each feature, both compare findings |

---

## Robustness Notes

- **Codex output is clean** — `-o file` writes only the agent's final message
- **Gemini stderr is noisy** — always use `2>/dev/null` to strip MCP init logs
- **Timeout**: 5 minutes for code review, 10 minutes for UAT evaluation
- **Not blocking** — external review is advisory; append error note on failure
- **Evidence capture** — for UAT dispatch, screenshots must be captured BEFORE dispatching
  the CLI agent. The harness generates capture instructions, not runtime automation
- **No retry/parsing infrastructure** — the harness keeps it simple; if complex
  retry logic or 4-tier parsing is needed, that belongs in an orchestrator layer
