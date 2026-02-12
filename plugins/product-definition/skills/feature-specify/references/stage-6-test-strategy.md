---
stage: stage-6-test-strategy
artifacts_written:
  - specs/{FEATURE_DIR}/test-plan.md (conditional)
---

# Stage 6: Testability & Risk Assessment (Coordinator) — Optional

> This stage generates a test strategy focused on risk assessment, testability verification,
> and test level guidance. Individual test definitions are deferred to the planning phase.
> Entirely optional — controlled by `feature_flags.enable_test_strategy`.

## CRITICAL RULES (must follow — failure-prevention)

1. **Feature flag check**: Skip entirely if `enable_test_strategy == false`
2. **Required inputs**: `spec.md` AND `design-brief.md` MUST exist
3. **Testability verification**: Every AC must be checked — flag non-testable ACs
4. **No individual test IDs**: Define test categories and levels, not individual tests
5. **No implementation references**: No component names, class names, architecture patterns
6. **NEVER interact with users directly**: signal `needs-user-input` if issues found

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

Check for additional inputs that enhance analysis:
- `specs/{FEATURE_DIR}/analysis/mpa-edgecases*.md` — for edge case identification
- `specs/{FEATURE_DIR}/design-supplement.md` — for visual test targets

## Step 6.4: Launch QA Strategist

Dispatch via `Task(subagent_type="general-purpose")`:

```
## Task: Generate Test Strategy

Read the agent instructions: @$CLAUDE_PLUGIN_ROOT/agents/qa-strategist.md
Load reference templates: @$CLAUDE_PLUGIN_ROOT/agents/qa-references/sequential-thinking-templates.md

Spec: @specs/{FEATURE_DIR}/spec.md
Design Brief: @specs/{FEATURE_DIR}/design-brief.md
{IF mpa-edgecases*.md exists: Edge Cases: @specs/{FEATURE_DIR}/analysis/mpa-edgecases-parallel.md}
{IF design-supplement.md exists: Design Supplement: @specs/{FEATURE_DIR}/design-supplement.md}

Template: @$CLAUDE_PLUGIN_ROOT/templates/test-plan-template.md
Output: specs/{FEATURE_DIR}/test-plan.md

Use Sequential Thinking (if available, 4 thoughts):
1. Risk assessment — failure modes across 6 categories
2. Testability verification — every AC checked
3. Critical user journeys and edge cases
4. Synthesis — test level guidance, risk summary, deferred items
```

## Step 6.5: Parse Response

Extract from agent output:
- `risk_areas`: {critical: N, high: N, medium: N}
- `acs_total`: total acceptance criteria
- `acs_testable`: ACs verified as testable
- `acs_needs_revision`: ACs flagged as not testable
- `critical_journeys`: number of identified journeys
- `edge_cases`: number of identified edge cases

## Step 6.6: Validate Testability

**If `acs_needs_revision` > 0:**

Signal `needs-user-input`:
```yaml
flags:
  pause_type: "interactive"
  block_reason: "{N} acceptance criteria are not testable as written"
  question_context:
    question: "Test strategy found {N} acceptance criteria that are not testable. These need spec revision. How to proceed?"
    header: "Testability"
    options:
      - label: "View and address (Recommended)"
        description: "See the non-testable ACs and revise them"
      - label: "Proceed with gaps"
        description: "Accept current testability and continue"
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
    risk_areas:
      critical: {N}
      high: {N}
      medium: {N}
    acs_total: {N}
    acs_testable: {N}
    acs_needs_revision: {N}
    critical_journeys: {N}
    edge_cases: {N}
```

## Summary Contract

> **Size limits:** `summary` max 500 chars, Context body max 1000 chars. Details in artifacts, not summaries.

```yaml
---
stage: "test-strategy"
stage_number: 6
status: completed | needs-user-input
checkpoint: TEST_STRATEGY
artifacts_written:
  - specs/{FEATURE_DIR}/test-plan.md
summary: "Test strategy: {N} risks ({C} critical), {T}/{TOTAL} ACs testable, {J} critical journeys, {E} edge cases."
flags:
  risk_critical: {N}
  risk_high: {N}
  acs_total: {N}
  acs_testable: {N}
  acs_needs_revision: {N}
  critical_journeys: {N}
  edge_cases: {N}
  block_reason: null | "{reason}"
  pause_type: null | "interactive"
  question_context: {see above if needs-user-input}
---

## Context for Next Stage
Test strategy generated. {N} risks identified ({C} critical). {T}/{TOTAL} ACs testable.
{IF acs_needs_revision > 0: "{N} ACs need revision for testability."}
```

## Self-Verification (MANDATORY before writing summary)

BEFORE writing the summary file, verify:
1. `specs/{FEATURE_DIR}/test-plan.md` exists (if not skipped)
2. Risk areas are populated (not placeholder values)
3. Testability verification covers all ACs
4. No individual test IDs in the output (UT-NNN, INT-NNN, etc.)
5. State file updated with stage 6 checkpoint data
6. Summary YAML frontmatter has no placeholder values

## CRITICAL RULES REMINDER

- Feature flag check first — skip entirely if disabled
- Required inputs: spec.md AND design-brief.md must exist
- Testability verification for every AC — flag non-testable ACs
- No individual test IDs — categories and levels only
- No implementation references
- NEVER interact with users directly
