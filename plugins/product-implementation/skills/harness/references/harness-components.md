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
  "feature-list.json"  # descriptions are immutable
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

## 2c. Evaluation Criteria

### Why Separate Evaluation Matters

From Anthropic's research: models "confidently praise their own work — even when, to a
human observer, the quality is obviously mediocre." The fix is to define concrete criteria
BEFORE building, shared with both the generator (the coding agent) and the evaluator
(a separate session that reviews the work).

### Defining Quality Dimensions

Choose 3-5 dimensions relevant to the project domain. Each dimension needs:
- A clear name
- What it measures (1 sentence)
- Scoring rubric (1-5 scale with brief description per level)
- Threshold: minimum passing score (blocking) or advisory

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

## Evaluator Prompt

Use this prompt to start a fresh Claude session for evaluation:

> You are evaluating the implementation of {feature_name}. Your job is to grade the work
> against the criteria below — not to fix or improve anything. Be skeptical: assume the
> builder thinks everything is fine, and your job is to verify that claim.
>
> 1. Read `{feature_dir}/.harness/feature-list.json` and check each feature's `passes` claim
> 2. For each feature marked `passes: true`, verify it actually works
> 3. Score each dimension below from 1-5 with evidence
> 4. Any blocking dimension below threshold = FAIL with specific issues
>
> {paste dimensions here}
```

### Few-Shot Calibration

If the codebase has existing code that represents "good" quality, reference specific files
or patterns in the evaluation criteria so the evaluator has concrete examples to calibrate
against, rather than relying solely on abstract descriptions.

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

```markdown
# Session Startup — {feature_name}

When beginning a new coding session, follow these steps in order:

1. **Orient**: Read this file and `progress.md` to understand current state
2. **Check git**: Run `git log --oneline -10` and `git status` for recent history
3. **Read feature list**: Open `.harness/feature-list.json`, find first `passes: false`
4. **Verify baseline**: Run `{build_command}` and `{test_command}` to confirm clean state
5. **Sprint contract**: Before coding, write a brief contract in progress.md:
   - Which feature(s) you'll work on this session
   - What "done" looks like (tests to write, behavior to verify)
6. **Work**: Implement one feature at a time. Test each before moving to the next.
7. **Wrap up**: Update `progress.md`, update `feature-list.json` passes, commit work.
```

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

```markdown
# Sprint Contract — {date}

## Scope
Feature(s) to implement this session:
- {feature_id}: {description}

## Definition of Done
- [ ] All acceptance criteria from feature-list.json are met
- [ ] Tests written and passing
- [ ] Build succeeds
- [ ] Code committed with descriptive message

## Out of Scope
{anything explicitly NOT being done this session — prevents scope creep}
```

### Iteration Pattern

Recommend this pattern to users — it prevents the two most common agent failure modes
(context exhaustion from doing too much, and premature victory from skipping verification):

1. **Pick ONE feature** from feature-list.json (first `passes: false`)
2. **Write tests first** if test-plan exists for this feature
3. **Implement** until tests pass
4. **Verify** — run full test suite, check build
5. **Update** — mark `passes: true` in feature-list.json, update progress.md
6. **Commit** with descriptive message referencing the feature ID
7. **Repeat** from step 1

### Entropy Management

Over many sessions, the codebase will drift. Recommend periodic cleanup:
- **Every 5 features**: Review and update ARCHITECTURE.md if design evolved
- **Every 10 features**: Run full lint + test suite, fix any accumulated warnings
- **End of plan**: Final review session with evaluation criteria, update docs
