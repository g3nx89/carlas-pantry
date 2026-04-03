# Harness Components — Templates & Guidance

Detailed templates for each of the 6 harness component categories. Read only the section
relevant to the category you're currently configuring.

---

## 2a. Knowledge Store

### CLAUDE.md Augmentation

Append a section to the project's existing CLAUDE.md. Never overwrite existing content.
Keep the addition under ~100 lines. Structure it as a map that tells the agent WHERE to
look, not WHAT to do in every situation.

**Template:**

```markdown
## Implementation Harness

### Quick Reference
- Build: `{build_command}`
- Test: `{test_command}`
- Lint: `{lint_command}`
- Run: `{run_command}`

### Architecture
See `docs/ARCHITECTURE.md` for system design, component relationships, and data flow.

### Active Plan
Feature: {feature_name}
Plan: `{feature_dir}/plan.md`
Progress: `{feature_dir}/.harness/feature-list.json`
Session startup: `{feature_dir}/.harness/session-startup.md`

### Conventions
- {convention_1 — e.g., "All API endpoints return envelope: { data, error, meta }"}
- {convention_2 — e.g., "Tests co-located with source: foo.ts → foo.test.ts"}
- {convention_3 — e.g., "Commits follow conventional commits: feat/fix/refactor(scope)"}

### Pitfalls
- {pitfall_1 — e.g., "Don't import from @internal/* — these are build-time only"}
- {pitfall_2 — e.g., "The DB migration tool auto-generates — never edit migrations manually"}
```

**Tailoring guidance:**
- Extract build/test/run commands from package.json scripts, Makefile targets, or build.gradle tasks
- Pull conventions from existing CLAUDE.md, .editorconfig, linter configs, or codebase patterns
- Pitfalls come from the plan's "risks" section and from analyzing common mistakes in the codebase

### docs/ARCHITECTURE.md

Generate only if the project doesn't already have one. Source from `plan.md` and `design.md`.

**Template:**

```markdown
# Architecture — {feature_name}

## System Overview
{1-2 paragraph summary of what the system does and its main components}

## Component Map
{List key modules/packages with one-line descriptions and their relationships}

## Data Flow
{How data moves through the system — request lifecycle, event flow, etc.}

## Key Decisions
{Architectural decisions from plan.md with brief rationale}

## Dependencies
{External services, APIs, databases with their roles}
```

---

## 2b. Enforcement Layer

### Principles

Hooks should be:
- **Fast** — a hook that takes 30s will frustrate the model into finding workarounds
- **Deterministic** — same input always produces same result
- **Informative** — on failure, explain what went wrong and how to fix it
- **Minimal** — start with 2-3 essential hooks, add more only when problems arise

### Hook Configuration

Add hooks to `.claude/settings.json`. If the file exists, merge — don't overwrite.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "command": ".claude/scripts/verify-build.sh",
        "description": "Verify build after code changes"
      }
    ],
    "PreCommit": [
      {
        "command": ".claude/scripts/verify-tests.sh",
        "description": "Run tests before committing"
      }
    ]
  }
}
```

### Lint Scripts with Remediation

Every lint script should print remediation instructions on failure. This is critical —
the model reads stderr/stdout and uses it to self-correct. A lint that just says "FAIL"
wastes a retry; a lint that says "FAIL: missing test for new function `handleAuth` —
add a test file at src/__tests__/handleAuth.test.ts" fixes the problem immediately.

**Script template:**

```bash
#!/bin/bash
# .claude/scripts/verify-build.sh
# Remediation-aware build verification

set -euo pipefail

if ! {build_command} 2>&1; then
  echo "BUILD FAILED"
  echo ""
  echo "Remediation:"
  echo "  1. Check the error above for the failing file and line"
  echo "  2. Fix the compilation/type error"
  echo "  3. Run '{build_command}' to verify the fix"
  exit 1
fi
```

### Spec Protection

Generate a hook that prevents modification of plan artifacts:

```bash
#!/bin/bash
# .claude/scripts/protect-specs.sh
# Prevent accidental modification of planning artifacts

PROTECTED_PATTERNS=(
  "tasks.md"
  "plan.md"
  "design.md"
  "test-plan.md"
)

for file in "$@"; do
  for pattern in "${PROTECTED_PATTERNS[@]}"; do
    if [[ "$file" == *"$pattern" ]]; then
      echo "BLOCKED: Cannot modify planning artifact: $file"
      echo ""
      echo "These files are the source of truth from the planning phase."
      echo "If the plan needs changes, discuss with the user first."
      exit 1
    fi
  done

  # feature-list.json: only the "passes" field may change
  if [[ "$file" == *"feature-list.json" ]]; then
    echo "WARNING: feature-list.json modified. Only the 'passes' field should change."
    echo "Do NOT edit descriptions, acceptance_criteria, or dependencies."
    echo "If you need to change the plan, discuss with the user first."
    # Warning only — not blocking, because the coding agent must update passes
  fi
done
```

### Recommended Starter Set

Based on quality bar preference:

| Quality Bar | Hooks |
|------------|-------|
| Fast iteration | PreCommit: tests only |
| Balanced | PostToolUse(Edit/Write): build verify; PreCommit: tests |
| Thorough | PostToolUse(Edit/Write): build+lint; PreCommit: tests+coverage; spec protection |

---

## 2c. Evaluation Criteria & Evaluation Loop

### Why Separate Evaluation Matters

From Anthropic's research: models "confidently praise their own work — even when, to a
human observer, the quality is obviously mediocre." The fix is to define concrete criteria
BEFORE building, shared with both the generator (the coding agent) and the evaluator
(a separate session that reviews the work).

### Evaluation Modes

The harness supports two evaluation modes. Choose based on the user's quality bar and
available tools:

| Mode | What It Does | When to Use |
|------|-------------|-------------|
| **Code Review** | Evaluator reads code, runs tests, grades against criteria | Always available; minimum evaluation |
| **Evaluation Loop (UAT)** | Evaluator interacts with the RUNNING app as a user would | When app has UI + interaction tools available |

Code Review is always configured. The Evaluation Loop is opt-in — enable it when the
project has a runnable UI and appropriate MCP tools (Playwright for web, mobile-mcp for
mobile). Read `evaluation-loop.md` for full details on the evaluation loop.

### Defining Quality Dimensions

Choose 3-5 dimensions relevant to the project domain. Each dimension needs:
- A clear name
- What it measures (1 sentence)
- Scoring rubric (1-5 scale with brief description per level)
- Threshold: minimum passing score (blocking) or advisory
- **Hard threshold rule**: if ANY single blocking dimension scores below its threshold,
  the sprint verdict is FAIL. No averaging across dimensions — one critical failure blocks.

**Domain-specific dimension suggestions:**

| Domain | Suggested Dimensions |
|--------|---------------------|
| Frontend | Visual fidelity, Accessibility, Responsiveness, Interaction completeness |
| Backend | API correctness, Error handling, Performance, Security |
| Android | Material Design compliance, Lifecycle handling, Performance, Accessibility |
| Fullstack | E2E flow completeness, API contract compliance, UI/UX quality, Test coverage |

**Template for eval-criteria.md:**

```markdown
# Evaluation Criteria — {feature_name}

## Dimensions

### 1. {Dimension Name}
**Measures:** {what this evaluates}
**Weight:** {blocking | advisory}

| Score | Description |
|-------|-------------|
| 1 | {critical failure — e.g., "Core feature doesn't work at all"} |
| 2 | {major issues — e.g., "Feature works but with significant bugs"} |
| 3 | {acceptable — e.g., "Feature works correctly, minor rough edges"} |
| 4 | {good — e.g., "Feature works well, handles edge cases"} |
| 5 | {excellent — e.g., "Feature is polished, robust, well-tested"} |

**Minimum passing score:** {3 for blocking, N/A for advisory}

{repeat for each dimension}

## Hard Threshold Rule

If ANY blocking dimension scores below its minimum, verdict is FAIL — regardless of other
scores. This prevents the evaluator from averaging away real problems.

## Verdict Rules

- **PASS** — All blocking dimensions ≥ threshold, weighted score ≥ 80%
- **REVISE** — All blocking dimensions ≥ threshold, but weighted score 65-79% or advisory issues
- **FAIL** — Any single blocking dimension below threshold

## Dimension Weights (optional)

Assign percentage weights to dimensions. If omitted, all blocking dimensions are equally weighted.

| Dimension | Weight | Blocking |
|-----------|--------|----------|
| {name} | {N}% | yes/no |
| ... | ... | ... |
| **Total** | **100%** | |
```

<!-- CONFIGURATOR: Evaluator Prompt -->
<!-- For the full evaluator session prompt template, see evaluation-loop.md Section 4a.
That template includes critical rules, tool inventory, calibration examples, and output
format. Use the template and fill in project-specific details. Write the result to
evaluator-prompt.md as a separate file, not inside eval-criteria.md. -->

### Few-Shot Calibration

Include 2-3 grading examples in the evaluator prompt to calibrate rigor. Without these,
evaluators tend to be lenient — finding real issues but talking themselves into approving.

**Example calibration entry:**
```markdown
## Calibration Example — Score: 2 (FAIL)
Criterion: "User can create a project and see it in the list"
Evidence: Form works, but list doesn't refresh after creation. User must reload manually.
Why not 3: Auto-refresh is part of the criterion, not a nice-to-have.
```

If the codebase has existing code that represents "good" quality, reference specific files
or patterns so the evaluator has concrete examples, rather than relying solely on abstract
descriptions.

### Evaluator Tuning

After the first evaluation round, the user should review the evaluator's scores:
1. Read `.harness/eval-reports/` for the latest report
2. Flag any scores that seem too lenient or too strict
3. Record observations in `.harness/evaluator-tuning-log.md`
4. Update the evaluator prompt's calibration examples to correct drift

Template for `evaluator-tuning-log.md`:

    # Evaluator Tuning Log

    ## Round {N} — {date}
    **Observation:** {what the evaluator scored vs what you expected}
    **Adjustment:** {how the evaluator prompt was updated}
    **Rationale:** {why this calibration matters}

This is an iterative process — expect 2-3 rounds of tuning over the project lifetime.
Calibration drift is normal as the codebase evolves.

### Evaluation Loop Configuration

When the user wants interactive UAT evaluation (not just code review), read
`$CLAUDE_PLUGIN_ROOT/skills/harness/references/evaluation-loop.md` and configure:

1. **Sprint contract template** — Coder and evaluator agree on testable "done" criteria
   before coding starts. Prevents scope drift and gives the evaluator concrete items to test.

2. **Evaluator session prompt** — A calibrated prompt for a SEPARATE Claude session that
   tests the running app. Includes platform-specific tools, launch instructions, criteria,
   and few-shot calibration examples.

3. **App launch script** — `.claude/scripts/launch-app.sh` that starts the dev server and
   waits for readiness. The evaluator runs this before testing.

4. **Feedback re-ingestion** — The evaluator writes `.harness/evaluation-report.md`; the
   coder reads it next session and addresses issues before new work.

If external CLI agents are available (Codex, Gemini), also configure UAT dispatch scripts.
Read `cli-agents.md` Section 3 for UAT-specific dispatch patterns.

---

## 2d. Progress Tracking

### Feature List JSON

See `feature-list-schema.md` for the full schema and conversion algorithm.

### Progress File Template

```markdown
# Progress — {feature_name}

## Last Updated
{timestamp} — Session {N}

## Completed
- [x] {task_id}: {description} (commit: {hash})
- [x] {task_id}: {description} (commit: {hash})

## In Progress
- [ ] {task_id}: {description}
  - Status: {what's done so far}
  - Blockers: {any blockers, or "none"}

## Next Up
- {task_id}: {description}

## Session Notes
{anything the next session should know — gotchas discovered, decisions made, etc.}
```

### Session Startup Checklist

    # Session Startup — {feature_name}

    When beginning a new coding session, follow these steps in order:

    1. **Orient**: Read this file and `progress.md` to understand current state
    2. **Check git**: Run `git log --oneline -10` and `git status` for recent history
    3. **Read feature list**: Open `.harness/feature-list.json`, find first `passes: false`
    4. **Verify baseline**: Run `{build_command}` and `{test_command}` to confirm clean state

    ## If evaluation loop is enabled:
    4b. **Check evaluation reports**: Read the latest file in `.harness/eval-reports/`:
        - If FAIL: address ALL critical issues before starting new work
        - If REVISE: address critical issues, note advisory issues for later
        - If PASS: proceed to next feature
        - Check score trend: if scores flat/declined for 2+ rounds, consider pivoting

    ## If external CLI agents are configured:
    4c. **Check CLI reviews**: Read `.harness/last-review.md` and any `cli-uat-*` files
        in `.harness/eval-reports/`. Address any CRITICAL findings before new work.

    5. **Sprint contract**: Before coding, write a sprint contract:
       - Which feature(s) you'll work on this session
       - Concrete acceptance verification criteria (see sprint contract template)
    6. **Work**: Implement one feature at a time. Test each before moving to the next.
    7. **Commit**: Commit work with descriptive message. Update `progress.md`.

    ## If evaluation loop is enabled:
    8. **Trigger evaluation**: Start a fresh evaluator session using
       `.harness/evaluator-prompt.md`. The evaluator tests the running app and writes
       a report to `.harness/eval-reports/`.
    9. **Mark done**: Set `passes: true` in `feature-list.json` ONLY after evaluation
       verdict is PASS or REVISE (no critical issues). Do NOT mark passes before evaluation.

    ## If evaluation loop is NOT enabled:
    8b. **Mark done**: Set `passes: true` after tests pass and build succeeds (step 7).

    ## If external CLI agents are configured:
    10. **External review**: Run `.claude/scripts/external-review.sh` and/or
        `.claude/scripts/uat-dispatch.sh` for independent evaluation.

---

## 2e. Tooling Setup

### MCP Server Recommendations

| Domain | Recommended MCPs | Why |
|--------|-----------------|-----|
| Frontend/Web | Playwright | Browser testing, E2E verification, screenshot comparison |
| Mobile (Android) | mobile-mcp | Emulator interaction, UI testing, screenshot capture |
| Mobile (iOS) | mobile-mcp | Simulator interaction, UI testing |
| Design-heavy | Figma (figma-console) | Visual reference, design token extraction, parity checks |
| API/Backend | — | Usually no extra MCPs needed; curl/httpie suffice |

### Skill Recommendations

| Domain | Useful Skills | Why |
|--------|--------------|-----|
| Any | code-review | Structured review with severity-rated feedback |
| Any | tdd:test-driven-development | TDD workflow enforcement |
| Frontend | ui-design:* | Component patterns, accessibility, responsive design |
| Android | ui-design:mobile-android-design | Material Design 3, Compose patterns |
| iOS | ui-design:mobile-ios-design | HIG compliance, SwiftUI patterns |

### Build/Test Command Discovery

Check these locations for commands (in order):
1. `package.json` → `scripts` section
2. `Makefile` / `Justfile` → target names
3. `build.gradle` / `build.gradle.kts` → task names
4. `Cargo.toml` → standard cargo commands
5. `pyproject.toml` → tool configurations
6. Existing CI config (`.github/workflows/`, `.gitlab-ci.yml`) → step commands

---

## 2f. Workflow Guide

### Sprint Contract Template

The sprint contract is an agreement between coder and evaluator on what "done" looks like.
It prevents scope drift and gives the evaluator concrete, testable criteria.

**Critical:** Fill ALL placeholders with project-specific content. The output file should
contain ONLY the filled contract — no template instructions, no "How to Use" sections,
no "Negotiation protocol" text, no examples. Everything below marked `<!-- CONFIGURATOR -->`
is guidance for YOU (the configurator), not content for the output file.

    # Sprint Contract — {date}

    ## Scope
    Feature(s) from feature-list.json:
    - {feature_id}: {description}

    ## Acceptance Verification

    | # | Criterion | How to Verify | Tool |
    |---|-----------|--------------|------|
    | 1 | {concrete, testable behavior} | {specific test action} | {Playwright/mobile-mcp/curl} |
    | 2 | {error state or edge case} | {how to trigger and verify} | {tool} |
    | ... | ... | ... | ... |

    ## Definition of Done
    - [ ] All acceptance criteria verified (table above)
    - [ ] Tests written and passing
    - [ ] Build succeeds
    - [ ] Code committed with descriptive message
    - [ ] {If eval loop: evaluation report verdict is PASS or REVISE}
    - [ ] {If human review: PR submitted for review}

    ## Out of Scope
    {explicitly excluded items — prevents scope creep}

    ## Review Plan
    - Evaluation method: {native evaluator / CLI review / both}
    - Review scope: {changed files / --uncommitted / --base main}

<!-- CONFIGURATOR: The following is guidance for you, not output content. -->
<!-- Negotiation protocol: Before each sprint, the coder writes this contract. If evaluation
loop is enabled, the evaluator reviews it (max 2 rounds). On disagreement after 2 rounds,
the evaluator's version wins (bias toward rigor). See evaluation-loop.md Section 3 for
the full negotiation protocol. Do NOT include this text in the generated sprint-contract.md. -->

### Iteration Pattern

Recommend this pattern to users — it prevents the two most common agent failure modes
(context exhaustion from doing too much, and premature victory from skipping verification):

1. **Pick ONE feature** from feature-list.json (first `passes: false`)
2. **Write tests first** if test-plan exists for this feature
3. **Implement** until tests pass
4. **Verify** — run full test suite, check build
5. **Commit** with descriptive message referencing the feature ID
6. **Evaluate** — if evaluation loop is enabled, trigger evaluator session or external review
7. **Mark done** — set `passes: true` in feature-list.json ONLY after evaluation verdict is
   PASS (or REVISE with no critical issues). If evaluation is not enabled, mark after step 5.
8. **Repeat** from step 1

The order matters: committing before evaluation lets the evaluator review the actual committed
code. But `passes: true` must wait for the evaluator's verdict — otherwise the agent declares
victory before independent verification, which is the "premature victory" anti-pattern.

### Entropy Management

Over many sessions, the codebase will drift. Recommend periodic cleanup:
- **Every 5 features**: Review and update ARCHITECTURE.md if design evolved
- **Every 10 features**: Run full lint + test suite, fix any accumulated warnings
- **End of plan**: Final review session with evaluation criteria, update docs

---

## Project-Specific Adaptation

The templates above are starting points. When generating harness artifacts, adapt them
to the specific project:
- Replace generic dimension names with domain-specific ones
- Fill sprint contract criteria with concrete behaviors from the plan
- Add project-specific pitfalls and conventions discovered during Stage 1 analysis
- Research the project's framework for idiomatic testing patterns
- If the project has existing quality standards (lint configs, coverage thresholds,
  accessibility requirements), encode them in the eval criteria

The harness should feel custom-built for the project, not a template with swapped names.
