# Phase 12: Completion

> **Source:** Extracted from `/product-definition:requirements` main orchestration

**Checkpoint:** `COMPLETE`

**Goal:** Finalize workflow, release lock, generate completion report, and provide next steps.

## Step 12.1: Generate Completion Report

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
| Executive Summary | COMPLETE |
| Product Definition | COMPLETE |
| Target Users | COMPLETE |
| ... | ... |

## Next Steps
1. Review PRD with stakeholders
2. Create Figma designs based on Screen Inventory
3. Create feature specifications for implementation
```

## Step 12.2: Release Lock

```bash
rm -f requirements/.requirements-lock
echo "Workflow lock released"
```

## Step 12.3: Final State Update

```yaml
current_phase: "COMPLETE"
phase_status: "completed"
completed_at: "{ISO_DATE}"
```

**Git Suggestion:**
```
git add requirements/
git commit -m "prd(req): PRD complete"
git tag prd-v{VERSION}.0.0
```

## Step 12.4: Display Next Steps

```markdown
## PRD Complete!

**File:** `requirements/PRD.md`

### Next Steps:

1. **Review** PRD.md with stakeholders
2. **Create Figma designs** based on Screen Inventory section
3. **Create feature specifications** for implementation

### Git Commands:
```bash
git push origin main --tags
```
```
