---
stage: stage-6-completion
artifacts_written:
  - requirements/completion-report.md
---

# Stage 6: Completion (Coordinator)

> This stage finalizes the workflow: lock release, completion report, and next steps.

## Step 6.1: Generate Completion Report

Create `requirements/completion-report.md`:

```markdown
# PRD Completion Report

## Summary
| Metric | Value |
|--------|-------|
| PRD Mode | {NEW|EXTEND} |
| Total Rounds | {N} |
| Questions Answered | {N} |
| Validation Score | {N}/20 |
| Research Reports | {N} |

## Generated Artifacts
- `requirements/PRD.md` - Product Requirements Document
- `requirements/decision-log.md` - Decision traceability
- `requirements/research/research-synthesis.md` - Research synthesis (if conducted)

## PRD Sections
| Section | Status |
|---------|--------|
| Executive Summary | {STATUS} |
| Product Definition | {STATUS} |
| Target Users | {STATUS} |
| Problem Analysis | {STATUS} |
| Value Proposition | {STATUS} |
| Core Workflows | {STATUS} |
| Feature Inventory | {STATUS} |
| Screen Inventory | {STATUS} |
| Business Constraints | {STATUS} |
| Assumptions & Risks | {STATUS} |

## Next Steps
1. Review PRD with stakeholders
2. Create Figma designs based on Screen Inventory
3. Create feature specifications for implementation
```

Populate metrics from state file and stage summaries.

## Step 6.2: Release Lock

```bash
rm -f requirements/.requirements-lock
```

## Step 6.3: Final State Update

```yaml
current_stage: 6
stage_status: "completed"
completed_at: "{ISO_DATE}"
```

## Step 6.4: Display Next Steps

```markdown
## PRD Complete!

**File:** requirements/PRD.md

### Next Steps:
1. **Review** PRD.md with stakeholders
2. **Create Figma designs** based on Screen Inventory section
3. **Create feature specifications** for implementation

### Git Commands:
git add requirements/
git commit -m "prd(req): PRD complete"
git tag prd-v{VERSION}.0.0
git push origin main --tags
```

## Summary Contract

```yaml
---
stage: "completion"
stage_number: 6
status: completed
checkpoint: COMPLETE
artifacts_written:
  - requirements/completion-report.md
summary: "PRD complete. {N} rounds, {M} questions answered. Score: {S}/20."
flags:
  total_rounds: {N}
  total_questions: {M}
  validation_score: {S}
---
```
