---
stage: stage-6-test-strategy
artifacts_written:
  - specs/{FEATURE_DIR}/test-plan.md (conditional)
---

# Stage 6: Test Strategy (Coordinator) — Optional

> This stage generates a comprehensive V-Model test strategy with full AC->Test traceability.
> Entirely optional — controlled by `feature_flags.enable_test_strategy`.

## CRITICAL RULES (must follow — failure-prevention)

1. **Feature flag check**: Skip entirely if `enable_test_strategy == false`
2. **Required inputs**: `spec.md` AND `design-brief.md` MUST exist
3. **100% AC coverage required**: Every acceptance criterion must map to at least one test
4. **TDD compliance**: Unit tests planned BEFORE implementation
5. **NEVER interact with users directly**: signal `needs-user-input` if coverage gaps

## Step 6.1: Check Feature Flag

Read `feature_flags.enable_test_strategy` from config.

**If disabled:**
Write skip summary and return:
```yaml
---
stage: "test-strategy"
stage_number: 6
status: completed
checkpoint: TEST_STRATEGY
artifacts_written: []
summary: "Test strategy skipped (feature flag disabled)"
flags:
  skipped: true
  reason: "feature_flag_disabled"
---
```

## Step 6.2: Validate Required Inputs

```bash
test -f "specs/{FEATURE_DIR}/spec.md" || echo "MISSING: spec.md"
test -f "specs/{FEATURE_DIR}/design-brief.md" || echo "MISSING: design-brief.md"
```

**If spec.md missing:** Set `status: failed` — critical error, spec should exist from Stage 2.

**If design-brief.md missing:** Set `status: failed` — should exist from Stage 5. Signal orchestrator to re-run Stage 5.

## Step 6.3: Gather Optional Context

Check for additional inputs that enhance test quality:
- `specs/{FEATURE_DIR}/figma_context.md` — for visual oracles
- `specs/{FEATURE_DIR}/analysis/mpa-edgecases*.md` — for edge case tests
- `specs/{FEATURE_DIR}/design-feedback.md` — for gap-informed tests

## Step 6.4: Launch QA Strategist

Dispatch via `Task(subagent_type="general-purpose")`:

```
## Task: Generate V-Model Test Strategy

Read the agent instructions: @$CLAUDE_PLUGIN_ROOT/agents/qa-strategist.md
Load reference templates: @$CLAUDE_PLUGIN_ROOT/agents/qa-references/sequential-thinking-templates.md

Spec: @specs/{FEATURE_DIR}/spec.md
Design Brief: @specs/{FEATURE_DIR}/design-brief.md
{IF figma_context.md exists: Figma: @specs/{FEATURE_DIR}/figma_context.md}
{IF mpa-edgecases*.md exists: Edge Cases: @specs/{FEATURE_DIR}/analysis/mpa-edgecases-parallel.md}
{IF design-feedback.md exists: Design Feedback: @specs/{FEATURE_DIR}/design-feedback.md}

Template: @$CLAUDE_PLUGIN_ROOT/templates/test-plan-template.md
Output: specs/{FEATURE_DIR}/test-plan.md

Use Sequential Thinking (if available, 8 thoughts):
1. Risk analysis across 7 categories
2. Critical flow identification from user stories
3. Unit test planning (TDD — tests before implementation)
4. Integration test planning (component boundaries)
5. E2E test planning (full user journeys with screenshots)
6. Visual test planning (Figma oracles or design-brief fallback)
7. Traceability matrix (AC → Test mapping)
8. Execution order and priority
```

## Step 6.5: Parse Response

Extract from agent output:
- `test_counts`: {unit: N, integration: N, e2e: N, visual: N}
- `ac_coverage_pct`: percentage of ACs with at least one test
- `acs_without_coverage`: list of ACs without tests
- `risk_coverage_pct`: percentage of identified risks with mitigations

## Step 6.6: Validate Coverage

**If `acs_without_coverage` > 0:**

Signal `needs-user-input`:
```yaml
flags:
  pause_type: "interactive"
  block_reason: "{N} acceptance criteria have no test coverage"
  question_context:
    question: "Test plan has {COVERAGE}% AC coverage. {N} acceptance criteria lack tests. How to proceed?"
    header: "Test Gaps"
    options:
      - label: "Add missing tests (Recommended)"
        description: "Re-run QA strategist to cover remaining ACs"
      - label: "Proceed with gaps"
        description: "Accept current coverage and continue"
      - label: "View gaps"
        description: "Display the uncovered acceptance criteria"
```

## Step 6.7: Verify Output

```bash
test -f "specs/{FEATURE_DIR}/test-plan.md" || echo "MISSING: test-plan.md"
```

**If missing:** Re-run QA strategist (Step 6.4). If still missing: signal `needs-user-input`.

## Step 6.8: Checkpoint

Update state file:
```yaml
current_stage: 6
stages:
  test_strategy:
    status: completed
    timestamp: "{ISO_TIMESTAMP}"
    test_counts:
      unit: {N}
      integration: {N}
      e2e: {N}
      visual: {N}
    ac_coverage_pct: {N}
    risk_coverage_pct: {N}
```

## Summary Contract

```yaml
---
stage: "test-strategy"
stage_number: 6
status: completed | needs-user-input
checkpoint: TEST_STRATEGY
artifacts_written:
  - specs/{FEATURE_DIR}/test-plan.md
summary: "Test strategy: {TOTAL} tests across 4 levels. AC coverage: {PCT}%. Risk coverage: {PCT}%."
flags:
  test_total: {N}
  test_unit: {N}
  test_integration: {N}
  test_e2e: {N}
  test_visual: {N}
  ac_coverage_pct: {N}
  risk_coverage_pct: {N}
  acs_without_coverage: {N}
  block_reason: null | "{reason}"
  pause_type: null | "interactive"
  question_context: {see above if needs-user-input}
---

## Context for Next Stage
Test plan generated with {TOTAL} tests: {UNIT} unit, {INT} integration, {E2E} e2e, {VIS} visual.
AC coverage: {PCT}%.
{IF gaps: "Uncovered ACs: {LIST}"}
```

## Self-Verification (MANDATORY before writing summary)

BEFORE writing the summary file, verify:
1. `specs/{FEATURE_DIR}/test-plan.md` exists (if not skipped)
2. AC coverage percentage is calculated (not placeholder)
3. All test IDs use correct format: UT-NNN, INT-NNN, E2E-NNN, VIS-NNN
4. State file updated with stage 6 checkpoint data
5. Summary YAML frontmatter has no placeholder values

## CRITICAL RULES REMINDER

- Feature flag check first — skip entirely if disabled
- Required inputs: spec.md AND design-brief.md must exist
- 100% AC coverage required
- TDD compliance: unit tests before implementation
- NEVER interact with users directly
