---
stage: stage-7-completion
artifacts_written:
  - specs/{FEATURE_DIR}/completion-report.md (in summary context)
---

# Stage 7: Completion (Coordinator)

> This stage finalizes the workflow: lock release, completion report, and next steps.

## CRITICAL RULES (must follow — failure-prevention)

1. **Lock MUST be released**: Remove `.specify.lock` before completing. A stale lock blocks future invocations.
2. **State file MUST record `current_stage: 7`**: With `stage_status: "completed"` and timestamp.
3. **All artifact paths in report must actually exist**: Verify before listing.

## Step 7.1: Generate Completion Report

Collect metrics from state file and stage summaries:

```markdown
# Feature Specification Completion Report

## Summary
| Metric | Value |
|--------|-------|
| Feature | {FEATURE_ID}: {FEATURE_NAME} |
| PAL Score | {SCORE}/20 ({DECISION}) |
| Checklist Coverage | {PCT}% |
| Clarifications Answered | {N} |
| Figma Integration | {enabled/disabled} ({SCREENS} screens) |
| Test Plan | {generated/skipped} ({TOTAL} tests) |

## Generated Artifacts
{FOR EACH artifact that exists:}
- `specs/{FEATURE_DIR}/{artifact}` — {description}

## Specification Metrics
| Metric | Count |
|--------|-------|
| User Stories | {N} |
| Acceptance Criteria | {N} |
| NFRs | {N} |
| Edge Cases Identified | {N} |
| Design Screens | {N} |

## Quality Gates
| Gate | Score | Status |
|------|-------|--------|
| Problem Quality | {N}/4 | {GREEN/YELLOW/RED/skipped} |
| True Need | {N}/4 | {GREEN/YELLOW/RED/skipped} |
| PAL Consensus | {N}/20 | {APPROVED/CONDITIONAL/REJECTED/skipped} |
| AC Test Coverage | {N}% | {status} |

## Next Steps
1. Review spec with stakeholders
2. Review test plan for TDD preparation
3. Run `/sdd:02-plan` to create implementation plan
4. Address any flagged gaps from design feedback
```

## Step 7.2: Release Lock

```bash
rm -f "specs/{FEATURE_DIR}/.specify.lock"
```

## Step 7.3: Final State Update

```yaml
current_stage: 7
stage_status: "completed"
completed_at: "{ISO_TIMESTAMP}"
next_step: "Review with stakeholders, then run /sdd:02-plan"
```

## Step 7.4: Present Next Steps

Include in summary context for orchestrator to display:

```markdown
## Specification Complete!

**Feature:** {FEATURE_ID} — {FEATURE_NAME}
**Spec:** specs/{FEATURE_DIR}/spec.md

### Generated Artifacts:
{list all existing artifacts}

### Next Steps:
1. **Review** spec.md with stakeholders
2. **Review** test-plan.md for TDD preparation (if generated)
3. **Run** `/sdd:02-plan` to create implementation plan
4. **Address** any gaps from design-feedback.md

### Git Commands:
git add specs/{FEATURE_DIR}/
git commit -m "spec({FEATURE_ID}): feature specification complete"
```

## Summary Contract

```yaml
---
stage: "completion"
stage_number: 7
status: completed
checkpoint: COMPLETE
artifacts_written: []
summary: "Specification complete for {FEATURE_ID}. PAL: {SCORE}/20. Coverage: {PCT}%. {N} clarifications. {T} tests planned."
flags:
  feature_id: "{FEATURE_ID}"
  pal_score: {N|null}
  coverage_pct: {N}
  clarifications_count: {N}
  test_count: {N|0}
  figma_enabled: {true|false}
---

## Completion Report
{Full completion report content from Step 7.1}
```

## Self-Verification (MANDATORY before writing summary)

BEFORE writing the summary file, verify:
1. Lock file has been removed (`.specify.lock` does NOT exist)
2. State file has `current_stage: 7` and `stage_status: "completed"`
3. All artifact paths listed in completion report actually exist
4. Summary YAML frontmatter has no placeholder values — all metrics populated

## CRITICAL RULES REMINDER

- Lock MUST be released — stale locks block future invocations
- State MUST be finalized with stage 7 and "completed" status
- All artifact paths in report must actually exist
