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

Check which CLI agents are available:

```bash
CODEX_AVAILABLE=$(command -v codex >/dev/null 2>&1 && echo true || echo false)
GEMINI_AVAILABLE=$(command -v gemini >/dev/null 2>&1 && echo true || echo false)
```

Record results in `analysis.json` under `available_tools.cli_agents`.

## Verified Invocation Patterns

These patterns have been tested and verified against codex-cli 0.116.0 and gemini 0.35.3.

### Codex

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

### Session Startup Addition

When CLI agents are configured, add this step to `session-startup.md`:

```markdown
6b. **Check for pending reviews**: Read `.harness/last-review.md` if it exists.
    Address any CRITICAL findings from the previous external review before
    starting new work.
```

### Sprint Contract Addition

```markdown
## Review Plan
- External review with: {codex|gemini|both}
- Review scope: {changed files since last review | --uncommitted | --base main}
```

## Configuration in analysis.json

```json
{
  "available_tools": {
    "cli_agents": {
      "codex": true,
      "gemini": true,
      "codex_version": "codex-cli 0.116.0",
      "gemini_version": "0.35.3"
    }
  },
  "harness_decisions": {
    "external_review": {
      "enabled": true,
      "strategy": "alternate",
      "frequency": "per_feature"
    }
  }
}
```

## Robustness Notes

- **Codex output is clean** — `-o file` writes only the agent's final message
- **Gemini stderr is noisy** — always use `2>/dev/null` to strip MCP init logs
- **Timeout**: 5 minutes default; codex and gemini both honor SIGTERM
- **Not blocking** — external review is advisory; append error note on failure
- **No retry/parsing infrastructure** — the harness keeps it simple; if complex
  retry logic or 4-tier parsing is needed, that belongs in an orchestrator layer
