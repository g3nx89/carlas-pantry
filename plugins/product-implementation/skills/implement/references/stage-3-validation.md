---
stage: "3"
stage_name: "Completion Validation"
checkpoint: "VALIDATION"
delegation: "coordinator"
prior_summaries:
  - ".stage-summaries/stage-1-summary.md"
  - ".stage-summaries/stage-2-summary.md"
artifacts_read:
  - "tasks.md"
  - "plan.md"
  - "spec.md"
artifacts_written:
  - ".implementation-state.local.md (updated stage)"
agents:
  - "product-implementation:developer"
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/implement/references/agent-prompts.md"
---

# Stage 3: Completion Validation

> **COORDINATOR STAGE:** This stage is dispatched by the orchestrator via `Task()`.
> Read the prior stage summaries first to understand execution results.

## 3.1 Validation Agent

Launch a `developer` agent for comprehensive validation using the prompt template from `agent-prompts.md` (Section: Completion Validation Prompt).

```
Task(subagent_type="product-implementation:developer")
```

**Key variables to prefill:**
- `{FEATURE_NAME}` — From Stage 1 summary
- `{FEATURE_DIR}` — From Stage 1 summary
- `{TASKS_FILE}` — From Stage 1 summary
- `{user_input}` — Original user arguments (if any)

## 3.2 Validation Checks

The validation agent verifies:

1. **Task completeness**: Every task in tasks.md is marked `[X]`
2. **Specification alignment**: Implemented features match the original spec
3. **Test coverage**: All tests pass, coverage meets project requirements
4. **Plan adherence**: Implementation follows the technical plan (architecture, patterns, file structure)
5. **Integration integrity**: All components integrate correctly

## 3.3 Validation Report

Agent produces a summary:

```text
## Implementation Validation Report

Tasks: {completed}/{total} (100%)
Tests: {passing}/{total} (100% pass rate)
Spec Coverage: {covered ACs}/{total ACs}

### Issues Found
- [severity] Description — file:line
- ...

### Recommendation
PASS / PASS WITH NOTES / NEEDS ATTENTION
```

## 3.4 Handling Validation Failures

If validation reveals issues, set `status: needs-user-input` in the stage summary with the validation report as the `block_reason`. The orchestrator will present options to the user:

**Options:**
1. **Fix now** — Launch developer agent to address specific issues, then re-validate
2. **Proceed to quality review anyway** — Continue with known issues
3. **Stop here** — Halt implementation

**Important:** The coordinator does NOT interact with the user directly. Write the summary with status `needs-user-input` and the orchestrator handles the interaction.

If orchestrator provides a user-input file with "Fix now":
1. Read `{FEATURE_DIR}/.stage-summaries/stage-3-user-input.md` for the user's decision
2. Launch developer agent to address specific issues
3. Re-validate
4. Rewrite the stage summary with updated results

## 3.5 Write Stage 3 Summary

Write summary to `{FEATURE_DIR}/.stage-summaries/stage-3-summary.md`:

```yaml
---
stage: "3"
stage_name: "Completion Validation"
checkpoint: "VALIDATION"
status: "completed"  # or "needs-user-input" if issues found
artifacts_written:
  - ".implementation-state.local.md"
summary: |
  Validation {passed/found issues}. Tasks: {N}/{M} complete.
  Tests: {all passing / N failures}. Spec coverage: {X}/{Y} ACs.
  Recommendation: {PASS / PASS WITH NOTES / NEEDS ATTENTION}.
flags:
  block_reason: null  # or full validation report if needs-user-input
  validation_outcome: "passed"  # passed | fixed | proceed_anyway | stopped
---
## Context for Next Stage

- Validation result: {PASS / PASS WITH NOTES / NEEDS ATTENTION}
- Tasks: {N}/{M} (100%)
- Tests: {all passing}
- Issues found: {count} ({severity breakdown})
- User decision: {if applicable}

## Validation Details

{Full validation report from agent}
```
