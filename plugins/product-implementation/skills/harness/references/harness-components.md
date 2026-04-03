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
Quality: `{feature_dir}/.harness/quality-score.json`
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
    "PreToolUse": [
      {
        "matcher": "Bash",
        "command": ".claude/scripts/verify-tests-on-commit.sh",
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
| Fast iteration | PreToolUse(Bash): test gate on commit |
| Balanced | PostToolUse(Edit/Write): build verify + import boundaries; PreToolUse(Bash): test gate; PostToolUse(Bash): entropy check |
| Thorough | PostToolUse(Edit/Write): build+lint + import boundaries + conventions; PreToolUse(Bash): tests+coverage; spec protection; PostToolUse(Bash): entropy check |

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

4. **Feedback re-ingestion** — The evaluator writes timestamped reports to
   `.harness/eval-reports/eval-{YYYY-MM-DD-HHmm}.md` (plus a `latest.md` copy); the
   coder reads the latest report next session and addresses issues before new work.

**UAT evaluation uses four mandatory layers** (read `cli-agents.md` Section 3):

5. **Maestro scripted regression** — For mobile projects, generates YAML E2E flows from
   sprint contract criteria. Runs autonomously (zero Claude tokens) as a session-startup
   smoke gate and post-feature regression check. Read `cli-agents.md` Section 3e for flow
   generation and invocation. Read `evaluation-loop.md` Section 2f for the evaluation
   interface.

6. **Native MCP UAT (primary)** — Playwright for web, mobile-mcp for mobile. The evaluator
   interacts with the running app in real time via MCP tools. Tests dynamic behavior (state
   transitions, animations, error states) that scripted regression cannot catch.

7. **Figma visual parity (mandatory)** — For all UI projects, the evaluator compares
   implementation screenshots against Figma design references using
   `figma_check_design_parity` (automated scoring) or `figma_capture_screenshot` (LLM
   comparison). Visual parity failures are blocking — any screen below the parity threshold
   must be addressed before marking `passes: true`. Read `evaluation-loop.md` Section 2e
   for the procedure. Requires a screen-to-frame map in `analysis.json`.

8. **CLI evidence review** — When Codex or Gemini CLIs are available, dispatch captured
   evidence for independent second-opinion review. Read `cli-agents.md` Section 3d for the
   dispatch script.

**All layers are mandatory** when the corresponding tools are available. If tools are
missing, the harness prompts the user to install them (Maestro, Playwright, mobile-mcp,
figma-console). Read `cli-agents.md` Section 3a for the detection procedure and install
checklist template. Users may decline — the gap is recorded in `analysis.json` and surfaced
in every evaluation report as reduced coverage.

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
    4a. **Check quality score**: Read `.harness/quality-score.json`:
        - If any dimension has `trend: declining` for 2+ entries, investigate before new work
        - Note dimensions to watch during this session

    ## If evaluation loop is enabled:
    4b. **Check evaluation reports**: Read the latest file in `.harness/eval-reports/`:
        - If FAIL: address ALL critical issues before starting new work
        - If REVISE: address critical issues, note advisory issues for later
        - If PASS: proceed to next feature
        - Check score trend: if scores flat/declined for 2+ rounds, consider pivoting

    ## If external CLI agents are configured:
    4c. **Check CLI reviews**: Read `.harness/last-review.md` and any `cli-uat-*` files
        in `.harness/eval-reports/`. Address any CRITICAL findings before new work.

    4d. **Verify Figma connection**: Call `figma_get_status` to confirm figma-console
        is connected. If disconnected:
        - Ensure Figma Desktop is running with the design file open
        - Ensure the Desktop Bridge Plugin is active
        - If connection cannot be restored, flag as coverage gap — visual parity is
          mandatory; proceed with reduced coverage and document the gap in eval report

    ## If Maestro is configured (mobile projects):
    4e. **Run Maestro smoke gate**: Execute `maestro test --include-tags=smoke --output
        .harness/eval-reports/maestro-smoke.xml .maestro/`
        - If ALL pass: proceed — no regressions detected
        - If ANY fail: fix regressions BEFORE starting new work. Read the JUnit XML
          report and check screenshots in `.harness/eval-evidence/maestro/`
        - This runs outside Claude (zero tokens) — do NOT skip it

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

    ## If evaluation loop is NOT enabled (visual parity still mandatory for UI features):
    10. **Visual parity check**: Run Figma visual parity standalone for each UI screen.
        Compare implementation screenshots against Figma designs (see cli-agents.md
        Section 3c for procedure). Screens scoring below parity threshold are blocking —
        address before marking `passes: true`.
        Note: when evaluation loop IS enabled (step 8), the evaluator prompt already
        includes visual parity — do NOT run it again as a separate step.

    ## If Maestro is configured (mobile projects):
    11. **Maestro post-feature regression**: Run the feature-specific Maestro flow +
        full smoke suite: `maestro test --output .harness/eval-reports/maestro-regression.xml .maestro/`
        - Confirms the new feature works AND nothing regressed
        - On pass: the feature flow joins the permanent smoke suite

    ## If external CLI agents are configured:
    12. **CLI evidence review**: Run `.claude/scripts/external-review.sh` for code review
        and/or `.claude/scripts/uat-dispatch.sh` to dispatch captured evidence for
        independent second-opinion review by Codex/Gemini.

    ## Entropy management (check every session):
    13. **Check cleanup state**: Compare completed features in `feature-list.json`
        against `next_major_at` in `.harness/last-cleanup.json`:
        - If completed >= next_major_at: **cleanup required** before new features:
          1. Run full test suite (and lint if configured): `{test_command}`
          2. Fix accumulated warnings
          3. Review `docs/ARCHITECTURE.md` — does it still match the code?
          4. Update `.harness/quality-score.json` dimensions
          5. Update `.harness/last-cleanup.json` with new thresholds
          6. Commit: `chore: entropy management after {N} features`
        - If completed >= next_minor_at: consider reviewing ARCHITECTURE.md for drift
        - Otherwise: proceed to step 5 (sprint contract)

### Quality Score

Track project health across sessions. The quality score is a JSON contract —
dimensions are set at configuration time, only `score`, `trend`, `evidence`, and
`history` are updated by the coding agent. Declining dimensions signal problems
that compound if ignored.

**Template for `quality-score.json`:**

```json
{
  "schema_version": 1,
  "feature_name": "{feature_name}",
  "last_updated": "{ISO 8601 timestamp}",
  "updated_after_feature": "{feature_id}",
  "overall_grade": "B",
  "dimensions": [
    {
      "name": "{dimension — e.g., Test Coverage}",
      "score": 3,
      "max": 5,
      "trend": "stable",
      "evidence": "{what supports this score}",
      "gap": "{what would raise the score, or null}"
    }
  ],
  "history": [
    {
      "date": "{ISO 8601}",
      "overall": "{letter grade}",
      "features_completed": 0,
      "scores": { "{dimension_name}": 3 },
      "note": "Initial baseline"
    }
  ]
}
```

**Dimension selection:** Choose 3-5 dimensions from `eval-criteria.md` that apply at
the project level (not per-sprint). Common choices:

| Domain | Suggested Dimensions |
|--------|---------------------|
| Any | Test Coverage, Build Health, Doc Freshness |
| Frontend | + Accessibility Conformance, Bundle Size |
| Backend | + API Contract Compliance, Error Handling |
| Android | + Material Design Conformance, Lifecycle Safety |
| Fullstack | + E2E Flow Coverage, Architecture Conformance |

**Grade derivation:** The letter grade is derived from dimension scores, not edited
directly. Rule: average of dimension scores → A (≥4.5), B (≥3.5), C (≥2.5), D (≥1.5), F (<1.5).

**Trend values:** `improving` | `stable` | `declining`. The agent compares current score
to the previous history entry's `scores` map to set the trend per dimension. Two
consecutive `declining` trends on any dimension should trigger investigation before
new feature work — the per-dimension `scores` in history make this comparison possible
across sessions.

**When to update:** After marking a feature as `passes: true` in feature-list.json,
update the relevant quality-score dimensions and append a history entry. Also update
during entropy management checkpoints.

### Last Cleanup Tracker

Track when the last entropy management pass occurred, so the entropy-check hook
(see `hooks-catalog.md`) can determine when cleanup is due.

**Template for `last-cleanup.json`:**

```json
{
  "completed_at_feature_count": 0,
  "date": "{ISO 8601 timestamp}",
  "actions_taken": ["initial baseline"],
  "next_minor_at": 5,
  "next_major_at": 10
}
```

The coding agent updates this file after completing an entropy management pass.
The thresholds (`next_minor_at`, `next_major_at`) are absolute feature counts — the
entropy-check hook compares them against the current completed count in feature-list.json.

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
8. **Update quality score** — update relevant dimensions in `quality-score.json`, append history entry
9. **Repeat** from step 1

The order matters: committing before evaluation lets the evaluator review the actual committed
code. But `passes: true` must wait for the evaluator's verdict — otherwise the agent declares
victory before independent verification, which is the "premature victory" anti-pattern.

### Entropy Management — "Constraints as Multipliers"

Over many sessions, the codebase will drift. Instead of relying on prose recommendations
the agent might forget, entropy management is enforced mechanically via the entropy-check
hook (see `hooks-catalog.md` "Entropy Management" section).

**How it works:**
1. The `PostToolUse(Bash)` entropy-check hook counts completed features in `feature-list.json`
2. It compares against thresholds stored in `.harness/last-cleanup.json`
3. At the minor threshold: prints a suggestion to review ARCHITECTURE.md
4. At the major threshold: prints a full cleanup checklist the agent should follow
5. After cleanup, the agent updates `last-cleanup.json` with new thresholds

**Default thresholds** (configurable in `last-cleanup.json`):
- **Minor** (every 5 features): Review ARCHITECTURE.md for drift, update quality-score.json
- **Major** (every 10 features): Full test sweep (+ lint if configured), fix warnings, dead code scan, doc update

**Lint conditional:** When generating the entropy-check script, only include `{lint_command}`
in the major-cleanup instructions if Stage 1b discovered a runnable lint command. Projects
without lint (common at balanced quality bar) should not have a placeholder lint reference.
- **End of plan**: Final review session with evaluation criteria — the agent runs a full
  cleanup regardless of thresholds when the last feature is marked `passes: true`

**Cleanup sprint contract:** For thorough quality bar, generate a cleanup-specific sprint
contract template alongside the regular one. The cleanup contract has its own verification
table focused on code health rather than feature behavior:

    # Cleanup Sprint Contract — {date}

    ## Scope
    Entropy management after {N} features completed.

    ## Checks
    | # | Check | How to Verify | Expected |
    |---|-------|--------------|----------|
    | 1 | Test suite clean | `{test_command}` | 0 failures, 0 new warnings |
    | 2 | Lint clean | `{lint_command}` | 0 new violations since last cleanup |
    | 3 | Architecture drift | Compare ARCHITECTURE.md vs actual imports | No undocumented cross-layer deps |
    | 4 | Dead code | Search for unused exports/functions | None introduced since last cleanup |
    | 5 | Doc freshness | ARCHITECTURE.md, CLAUDE.md last updated | Reflects current design |
    | 6 | Quality score | `.harness/quality-score.json` | No dimension with trend: declining |

    ## Completion
    - [ ] All checks pass
    - [ ] quality-score.json updated with new scores
    - [ ] last-cleanup.json updated with new thresholds
    - [ ] Committed: `chore: entropy management after {N} features`

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
